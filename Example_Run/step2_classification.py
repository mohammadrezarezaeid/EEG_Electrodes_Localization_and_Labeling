"""
STEP 2 - Per-vertex electrode classification with the trained MLPs
-------------------------------------------------------------------------
Applies the trained per-surface MLPs to the features of Step 1 and labels
every vertex of every head surface as electrode (1) or not (0).

One model per head surface: Trained_models/mlp_cell01.pt ... mlp_cell20.pt.
Each checkpoint holds its own weights, its own feature normalisation
(mean / std of the training subjects) and its own decision threshold.

FOLDER LAYOUT (relative to this script; nothing has to be moved)
    Trained_models/   mlp_cell01.pt ... mlp_cell20.pt   trained weights (provided)
    results/step1/    HC023_features_vertices.mat       features_vertices {20 x 1}
                      HC023_mesh_gt.mat                 Label_vertices    {20 x 1}
    results/step2/    output: HC023_pred.mat            predicted         {20 x 1}  0/1 per vertex (-> Step 3)
                                                        predicted_prob    {20 x 1}  electrode probability
                                                        predicted_idx     {20 x 1}  1-based indices of predicted vertices
                                                        metrics           [20 x 9]  surface, acc, recall, precision,
                                                                                    FPR, TP, FP, FN, TN

HOW TO RUN
    Locally (CPU, or GPU automatically if CUDA is available):
        python step2_classification.py

    In Google Colab (free GPU: Runtime > Change runtime type > GPU):
        1. Upload the repository folder to your Google Drive.
        2. In a Colab cell:
               from google.colab import drive
               drive.mount('/content/drive')
               !python "/content/drive/MyDrive/<repository folder>/step2_classification.py"

    Options (all optional):
        --root      repository folder (default: the folder of this script)
        --subject   subject name      (default: HC023)
        --device    auto | cpu | cuda (default: auto)

REQUIREMENTS
    Python 3.9+, numpy, scipy, PyTorch (https://pytorch.org/get-started/locally/)
"""

import argparse
import os
import sys

import numpy as np
import torch
import torch.nn as nn
from scipy.io import loadmat, savemat


# ------------------------------------------------------------------ model
class MLP(nn.Module):
    def __init__(self, input_size, hidden_size, num_classes, dropout=0.2):
        super(MLP, self).__init__()
        self.fc1 = nn.Linear(input_size, hidden_size)
        self.fc2 = nn.Linear(hidden_size, hidden_size)
        self.fc3 = nn.Linear(hidden_size, hidden_size)
        self.fc4 = nn.Linear(hidden_size, num_classes)
        self.relu = nn.ReLU()
        self.dropout = nn.Dropout(p=dropout)

    def forward(self, x):
        x = self.dropout(self.relu(self.fc1(x)))
        x = self.dropout(self.relu(self.fc2(x)))
        x = self.dropout(self.relu(self.fc3(x)))
        return self.fc4(x)


# ------------------------------------------------------------------ helpers
def script_folder():
    """Folder of this script, or the current folder when run interactively."""
    try:
        return os.path.dirname(os.path.abspath(__file__))
    except NameError:
        return os.getcwd()


def load_mat_variable(path, name, produced_by):
    if not os.path.isfile(path):
        sys.exit(f'Missing input {path} (expected from {produced_by}).')
    try:
        return loadmat(path)[name]
    except NotImplementedError:
        sys.exit(f'{path} is a MATLAB v7.3 file, which scipy cannot read. '
                 f"Save it in MATLAB with save(..., '-v7').")
    except KeyError:
        sys.exit(f"{path} does not contain the variable '{name}'.")


def pick_device(choice):
    if choice == 'cuda' and not torch.cuda.is_available():
        sys.exit('--device cuda was requested but no CUDA GPU is available.')
    if choice == 'auto':
        choice = 'cuda' if torch.cuda.is_available() else 'cpu'
    return torch.device(choice)


# ------------------------------------------------------------------ main
def main():
    parser = argparse.ArgumentParser(description='Step 2: per-vertex electrode classification.')
    parser.add_argument('--root', default=script_folder(), help='repository folder')
    parser.add_argument('--subject', default='HC023', help='subject name')
    parser.add_argument('--device', default='auto', choices=['auto', 'cpu', 'cuda'])
    args, _ = parser.parse_known_args()      # ignores extra arguments added by Jupyter/Colab

    model_dir     = os.path.join(args.root, 'Trained_models')
    step1_dir     = os.path.join(args.root, 'results', 'step1')
    results_dir   = os.path.join(args.root, 'results', 'step2')
    features_file = os.path.join(step1_dir, f'{args.subject}_features_vertices.mat')
    labels_file   = os.path.join(step1_dir, f'{args.subject}_mesh_gt.mat')
    out_path      = os.path.join(results_dir, f'{args.subject}_pred.mat')
    os.makedirs(results_dir, exist_ok=True)

    device = pick_device(args.device)
    print(f'Step 2 - {args.subject} - device: {device}')

    fv = load_mat_variable(features_file, 'features_vertices', 'Step 1')
    gt = load_mat_variable(labels_file, 'Label_vertices', 'Step 1')
    n_surfaces = fv.size

    pred_cells = np.empty((n_surfaces, 1), dtype=object)
    prob_cells = np.empty((n_surfaces, 1), dtype=object)
    idx_cells  = np.empty((n_surfaces, 1), dtype=object)
    metrics    = []

    for c in range(1, n_surfaces + 1):
        ckpt_path = os.path.join(model_dir, f'mlp_cell{c:02d}.pt')
        if not os.path.isfile(ckpt_path):
            sys.exit(f'Missing trained model {ckpt_path}.')
        ckpt = torch.load(ckpt_path, map_location='cpu', weights_only=True)

        model = MLP(ckpt['input_size'], ckpt['hidden_size'],
                    ckpt['num_classes'], ckpt['dropout'])
        model.load_state_dict(ckpt['state_dict'])
        model.to(device).eval()                         # dropout OFF

        X = np.asarray(fv.ravel()[c - 1], dtype=np.float64)
        y = np.zeros(X.shape[0], dtype=np.int64)
        y[np.asarray(gt.ravel()[c - 1]).ravel().astype(int) - 1] = 1

        Xs = (X - ckpt['scaler_mean'].numpy()) / ckpt['scaler_scale'].numpy()
        with torch.no_grad():
            logits = model(torch.tensor(Xs, dtype=torch.float32, device=device))
            prob = torch.softmax(logits, dim=1)[:, 1].cpu().numpy()
        pred = (prob >= ckpt['threshold']).astype(np.int64)

        tp = int(np.sum((pred == 1) & (y == 1)))
        fp = int(np.sum((pred == 1) & (y == 0)))
        fn = int(np.sum((pred == 0) & (y == 1)))
        tn = int(np.sum((pred == 0) & (y == 0)))
        acc  = (tp + tn) / (tp + tn + fp + fn)
        rec  = tp / max(tp + fn, 1)
        prec = tp / max(tp + fp, 1)
        fpr  = fp / max(fp + tn, 1)

        pred_cells[c - 1, 0] = pred.reshape(-1, 1)
        prob_cells[c - 1, 0] = prob.reshape(-1, 1)
        idx_cells[c - 1, 0]  = (np.flatnonzero(pred) + 1).reshape(-1, 1)   # MATLAB 1-based
        metrics.append([c, acc, rec, prec, fpr, tp, fp, fn, tn])

        print(f'[surface {c:2d}] acc {acc*100:5.2f}%  recall {rec*100:5.2f}%  '
              f'precision {prec*100:5.2f}%  FPR {fpr*100:5.2f}%  '
              f'TP {tp:5d}  FP {fp:6d}  FN {fn:5d}')

    metrics = np.array(metrics, dtype=np.float64)
    print('\nmean:  acc {:.2f}%  recall {:.2f}%  precision {:.2f}%  FPR {:.2f}%'
          .format(*(100 * metrics[:, 1:5].mean(axis=0))))

    savemat(out_path, {'predicted': pred_cells,
                       'predicted_prob': prob_cells,
                       'predicted_idx': idx_cells,
                       'metrics': metrics})
    print('saved', out_path)


if __name__ == '__main__':
    main()
