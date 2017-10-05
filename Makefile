.PHONY: test-up test-provision test-cleanup

test-up:
	something-is-borken

test-provision:
	vagrant provision

test-cleanup:
	CONTIV_ANSIBLE_PLAYBOOK="./cleanup.yml" CONTIV_ANSIBLE_TAGS="all" vagrant provision

test-test:
	CONTIV_ANSIBLE_TAGS="prebake-for-test" vagrant provision
