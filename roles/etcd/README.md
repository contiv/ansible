### Testing

Right now just install is under test

First setup molecule to run
```
virtualenv venv
. venv/bin/activate
pip install --upgrade pip
pip install -r molecule-requirements.txt
molecule converge
```

To shutdown
```
molecule destroy
```

To login to guest
```
molecule login --host etcd{1,2,3,-proxy}
```

