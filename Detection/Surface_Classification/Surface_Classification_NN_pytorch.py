# ============================================================
# MRI Mesh Segmentation (PyTorch + Leave-One-Subject-Out)
# ============================================================

import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from sklearn.metrics import accuracy_score, recall_score
from sklearn.preprocessing import StandardScaler
from scipy.io import loadmat, savemat
import os
import warnings
import time

# ================== OPTIONAL (COLAB ONLY) ==================
# Comment this if running locally
# from google.colab import drive
# drive.mount('/content/drive')

# ============================================================
# MODEL
# ============================================================

class MLP(nn.Module):
    def __init__(self, input_size, hidden_size, num_classes):
        super().__init__()

        self.net = nn.Sequential(
            nn.Linear(input_size, hidden_size),
            nn.ReLU(),
            nn.Dropout(0.2),

            nn.Linear(hidden_size, hidden_size),
            nn.ReLU(),
            nn.Dropout(0.2),

            nn.Linear(hidden_size, hidden_size),
            nn.ReLU(),
            nn.Dropout(0.2),

            nn.Linear(hidden_size, num_classes)
        )

    def forward(self, x):
        return self.net(x)


# ============================================================
# TRAIN / EVAL FUNCTIONS (STANDARD MODEL)
# ============================================================

def train_model(model, optimizer, criterion,
                X_train_tensor, y_train_tensor,
                num_epochs, batch_size, device):

    for epoch in range(num_epochs):
        model.train()
        epoch_loss = 0.0

        perm = torch.randperm(X_train_tensor.size(0))

        for i in range(0, X_train_tensor.size(0), batch_size):
            idx = perm[i:i + batch_size]

            x_batch = X_train_tensor[idx]
            y_batch = y_train_tensor[idx]

            outputs = model(x_batch)
            loss = criterion(outputs, y_batch)

            optimizer.zero_grad()
            loss.backward()
            optimizer.step()

            epoch_loss += loss.item()

        print(f"Epoch [{epoch+1}/{num_epochs}] Loss: {epoch_loss:.4f}")


def evaluate_model(model, X_test_tensor, y_test_tensor,
                   cell_idx, exclude_idx, device, save_dir):

    model.eval()

    with torch.no_grad():
        outputs = model(X_test_tensor)
        _, predicted = torch.max(outputs, 1)

        y_true = y_test_tensor.cpu().numpy()
        y_pred = predicted.cpu().numpy()

        acc = accuracy_score(y_true, y_pred)
        rec = recall_score(y_true, y_pred)

        print(f"Accuracy: {acc*100:.2f}% | Recall: {rec*100:.2f}%")

        os.makedirs(save_dir, exist_ok=True)
        save_path = os.path.join(save_dir, f"pred_cell_{cell_idx}_ex_{exclude_idx}.mat")

        savemat(save_path, {
            "predicted": y_pred,
            "y_test": y_true
        })


# ============================================================
# CONFIG
# ============================================================

file_range = range(3, 24)

main_features = "/content/drive/MyDrive/EEG-fMRI_data_64_electrodes/SavedFeatures_64electrodes"
main_labels   = "/content/drive/MyDrive/EEG-fMRI_data_64_electrodes/Meshgt_64elect"

num_subjects = len(file_range)

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# ============================================================
# MAIN LOOP
# ============================================================

for cell_idx in range(1, 21):

    for exclude_idx in range(20, 21):

        exclude_subject = file_range[exclude_idx]

        test_file = os.path.join(
            main_features,
            f"HC{exclude_subject:03d}_features_vertices.mat"
        )

        test_label_file = os.path.join(
            main_labels,
            f"HC{exclude_subject:03d}_mesh_gt.mat"
        )

        if not os.path.isfile(test_file) or not os.path.isfile(test_label_file):
            warnings.warn("Missing test files. Skipping...")
            continue

        # ================== LOAD TEST ==================

        data_test = loadmat(test_file)
        label_test = loadmat(test_label_file)

        X_test = data_test['features_vertices'][cell_idx - 1][0]
        TP_test = label_test['Label_vertices'][cell_idx - 1][0]

        y_test = np.zeros(X_test.shape[0], dtype=int)
        y_test[TP_test - 1] = 1

        # ================== TRAIN SET ==================

        X_train_list = []
        y_train_list = []

        start = time.time()

        for include_idx in range(num_subjects):

            include_subject = file_range[include_idx]

            if include_subject == exclude_subject:
                continue

            feat_file = os.path.join(
                main_features,
                f"HC{include_subject:03d}_features_vertices.mat"
            )

            label_file = os.path.join(
                main_labels,
                f"HC{include_subject:03d}_mesh_gt.mat"
            )

            if not os.path.isfile(feat_file) or not os.path.isfile(label_file):
                continue

            data = loadmat(feat_file)
            label = loadmat(label_file)

            X = data['features_vertices'][cell_idx - 1][0]
            TP = label['Label_vertices'][cell_idx - 1][0]

            y = np.zeros(X.shape[0], dtype=int)
            y[TP - 1] = 1

            X_train_list.append(X)
            y_train_list.append(y)

        X_train = np.vstack(X_train_list)
        y_train = np.concatenate(y_train_list)

        print(f"Dataset built | Cell {cell_idx} | Excluded HC{exclude_subject:03d}")
        print("Time:", time.time() - start)

        # ================== NORMALIZATION ==================

        scaler = StandardScaler()
        X_train = scaler.fit_transform(X_train)
        X_test = scaler.transform(X_test)

        # ================== TENSORS ==================

        X_train = torch.tensor(X_train, dtype=torch.float32).to(device)
        y_train = torch.tensor(y_train, dtype=torch.long).to(device)

        X_test = torch.tensor(X_test, dtype=torch.float32).to(device)
        y_test = torch.tensor(y_test, dtype=torch.long).to(device)

        # ================== MODEL ==================

        input_size = X_train.shape[1]
        hidden_size = 512
        num_classes = 2

        model = MLP(input_size, hidden_size, num_classes).to(device)

        criterion = nn.CrossEntropyLoss()
        optimizer = optim.Adam(model.parameters(), lr=0.001)

        # ================== TRAIN ==================

        train_model(model, optimizer, criterion,
                    X_train, y_train,
                    num_epochs=100,
                    batch_size=1024,
                    device=device)

        # ================== EVAL ==================

        evaluate_model(
            model,
            X_test,
            y_test,
            cell_idx,
            exclude_idx,
            device,
            save_dir=f"./results/nonweighted/cell_{cell_idx}"
        )
