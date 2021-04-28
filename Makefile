.PHONY: update-tags

update-tags:
	git checkout main
	git tag -s -f -a -m "latest series" latest
	git checkout -
	git push origin refs/tags/latest -f
