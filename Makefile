.PHONY: clean compile_translations coverage docs dummy_translations extract_translations \
	fake_translations help pull_translations push_translations quality \
	requirements swagger-ui test test-all upgrade validate

.DEFAULT_GOAL := help

define BROWSER_PYSCRIPT
import os, webbrowser, sys
from time import sleep
try:
	from urllib import pathname2url
except:
	from urllib.request import pathname2url

path_or_url = sys.argv[1]
delay = int(sys.argv[2]) if len(sys.argv) > 2 else 0
if delay > 0:
    sleep(delay)
if '://' in path_or_url:
    webbrowser.open(path_or_url)
else:
    webbrowser.open("file://" + pathname2url(os.path.abspath(path_or_url)))
endef
export BROWSER_PYSCRIPT
BROWSER := python -c "$$BROWSER_PYSCRIPT"

help: ## display this help message
	@echo "Please use \`make <target>' where <target> is one of"
	@perl -nle'print $& if m{^[a-zA-Z_-]+:.*?## .*$$}' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m  %-25s\033[0m %s\n", $$1, $$2}'

clean: ## remove generated byte code, coverage reports, and build artifacts
	find . -name '*.pyc' -exec rm -f {} +
	find . -name '*.pyo' -exec rm -f {} +
	find . -name '*~' -exec rm -f {} +
	coverage erase
	rm -fr build/
	rm -fr dist/
	rm -fr *.egg-info

compile_translations: ## compile translation files, outputting .po files for each supported language
	./manage.py compilemessages

coverage: clean ## generate and view HTML coverage report
	pytest --cov-report html
	$(BROWSER) htmlcov/index.html

docs: ## generate Sphinx HTML documentation, including API docs
	tox -e docs
	$(BROWSER) docs/_build/html/index.html

dummy_translations: ## generate dummy translation (.po) files
	cd user_tasks && i18n_tool dummy

extract_translations: ## extract strings to be translated, outputting .mo files
	./manage.py makemessages -l en -v1 -d django
	./manage.py makemessages -l en -v1 -d djangojs

fake_translations: extract_translations dummy_translations compile_translations ## generate and compile dummy translation files

upgrade: ## update the requirements/*.txt files with the latest packages satisfying requirements/*.in
	pip install -q pip-tools
	pip-compile --upgrade -o requirements/base.txt requirements/base.in
	pip-compile --upgrade -o requirements/dev.txt requirements/dev.in requirements/quality.in
	pip-compile --upgrade -o requirements/doc.txt requirements/base.in requirements/doc.in
	pip-compile --upgrade -o requirements/quality.txt requirements/quality.in
	pip-compile --upgrade -o requirements/test.txt requirements/base.in requirements/test.in
	pip-compile --upgrade -o requirements/travis.txt requirements/travis.in
	# Let tox control the Django version for tests
	sed '/Django==/d' requirements/test.txt > requirements/test.tmp
	mv requirements/test.tmp requirements/test.txt

pull_translations: ## pull translations from Transifex
	tx pull -a

push_translations: ## push source translation files (.po) from Transifex
	tx push -s

quality: ## check coding style with pycodestyle and pylint
	tox -e quality

requirements: ## install development environment requirements
	pip install -qr requirements/dev.txt --exists-action w
	pip-sync requirements/base.txt requirements/dev.txt requirements/private.* requirements/test.txt

swagger-ui: ## view Swagger UI for the REST API documentation
	tox -e docs
	$(BROWSER) http://localhost:8000 5 &
	echo "The REST API documentation should open in your browser within a few seconds"
	. .tox/docs/bin/activate; ./manage.py migrate --settings=schema.settings; SWAGGER_JSON_PATH=docs/swagger.json ./manage.py runserver --settings=schema.settings

test: clean ## run tests in the current virtualenv
	pytest

test-all: ## run tests on every supported Python/Django combination
	tox -e quality
	tox

validate: quality test ## run tests and quality checks
