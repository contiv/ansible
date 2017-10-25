.PHONY: test-up test-provision test-cleanup

test-up:
	vagrant up

test-provision:
	vagrant provision

test-cleanup:
	CONTIV_ANSIBLE_PLAYBOOK="./cleanup.yml" CONTIV_ANSIBLE_TAGS="all" vagrant provision

test-test:
	CONTIV_ANSIBLE_TAGS="prebake-for-test" vagrant provision

test-etcd:
	cd roles/etcd && virtualenv venv && . venv/bin/activate \
		&& pip install --upgrade pip \
		&& pip install -r molecule-requirements.txt \
		&& molecule converge && molecule destroy \
	|| (molecule destroy && exit 1)
