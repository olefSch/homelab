# not usable for security since it has gh deps
ci-job job:
	@echo "=== Simulating CI Job: {{job}} ==="
	act pull_request -j {{job}} \
		-P ubuntu-latest=catthehacker/ubuntu:full-latest \
		--container-architecture linux/amd64 \
		--secret GITHUB_TOKEN
