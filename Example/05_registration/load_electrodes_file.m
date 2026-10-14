function data = load_electrodes_file(filename)

    s = load(filename);
    f = fieldnames(s);
    data = s.(f{1});

end