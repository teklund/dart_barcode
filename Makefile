 # Copyright (C) 2020, David PHAM-VAN <dev.nfet.net@gmail.com>
 #
 # Licensed under the Apache License, Version 2.0 (the "License");
 # you may not use this file except in compliance with the License.
 # You may obtain a copy of the License at
 #
 #     http://www.apache.org/licenses/LICENSE-2.0
 #
 # Unless required by applicable law or agreed to in writing, software
 # distributed under the License is distributed on an "AS IS" BASIS,
 # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 # See the License for the specific language governing permissions and
 # limitations under the License.

FLUTTER?=$(realpath $(dir $(realpath $(dir $(shell which flutter)))))
FLUTTER_BIN=$(FLUTTER)/bin/flutter
DART_BIN=$(FLUTTER)/bin/dart
DART_SRC=$(shell find . -name '*.dart')
COV_PORT=9292

all: format

format: image/lib/src/pubspec.dart demo/.metadata flutter/example/.metadata format-dart

format-dart: $(DART_SRC)
	$(DART_BIN) format --fix $^

.coverage:
	which coverage || $(DART_BIN) pub global activate coverage
	touch $@

demo/.metadata:
	cd demo; $(FLUTTER_BIN) create -t app --no-overwrite --org net.nfet --project-name demo .
	rm -rf demo/test

flutter/example/.metadata:
	cd flutter/example; $(FLUTTER_BIN) create -t app --no-overwrite --org net.nfet --project-name example .
	rm -rf flutter/example/test

node_modules:
	npm install lcov-summary

test-barcode: .coverage
	cd barcode; $(DART_BIN) pub get
	cd barcode; $(DART_BIN) run test --coverage=.coverage
	cd barcode; $(DART_BIN) pub global run coverage:format_coverage --packages=.dart_tool/package_config.json -i .coverage --report-on lib --lcov --out ../lcov-barcode.info

test-image:
	cd image; $(DART_BIN) pub get
	cd image; $(DART_BIN) run test --coverage=.coverage
	cd image; $(DART_BIN) pub global run coverage:format_coverage --packages=.dart_tool/package_config.json -i .coverage --report-on lib --lcov --out ../lcov-image.info

test-flutter:
	cd flutter; $(FLUTTER_BIN) pub get
	cd flutter; $(FLUTTER_BIN) test --coverage
	mv flutter/coverage/lcov.info lcov-flutter.info

test: node_modules test-barcode test-image test-flutter barcodes
	lcov --add-tracefile lcov-barcode.info -t test1 -a lcov-example.info -t test2 -a lcov-image.info -t test3 -a lcov-flutter.info -t test4 -o lcov.info
	cat lcov.info | node_modules/.bin/lcov-summary

clean:
	git clean -fdx -e .vscode

publish-barcode: format clean
	test -z "$(shell git status --porcelain)"
	@find barcode -name pubspec.yaml -exec sed -i -e 's/^dependency_overrides:/_dependency_overrides:/g' '{}' ';'
	cd barcode; $(DART_BIN) pub publish -f
	@find barcode -name pubspec.yaml -exec sed -i -e 's/^_dependency_overrides:/dependency_overrides:/g' '{}' ';'
	git tag $(shell grep version barcode/pubspec.yaml | sed 's/version\s*:\s*/barcode-/g')

publish-flutter: format clean
	test -z "$(shell git status --porcelain)"
	@find flutter -name pubspec.yaml -exec sed -i -e 's/^dependency_overrides:/_dependency_overrides:/g' '{}' ';'
	cd flutter; $(DART_BIN) pub publish -f
	@find flutter -name pubspec.yaml -exec sed -i -e 's/^_dependency_overrides:/dependency_overrides:/g' '{}' ';'
	git tag $(shell grep version flutter/pubspec.yaml | sed 's/version\s*:\s*/barcode_widget-/g')

publish-image: format clean
	test -z "$(shell git status --porcelain)"
	@find image -name pubspec.yaml -exec sed -i -e 's/^dependency_overrides:/_dependency_overrides:/g' '{}' ';'
	cd image; $(DART_BIN) pub publish -f
	@find image -name pubspec.yaml -exec sed -i -e 's/^_dependency_overrides:/dependency_overrides:/g' '{}' ';'
	git tag $(shell grep version image/pubspec.yaml | sed 's/version\s*:\s*/barcode_image-/g')

.pana:
	$(DART_BIN) pub global activate pana
	touch $@

analyze-barcode: .pana
	@find barcode -name pubspec.yaml -exec sed -i -e 's/^dependency_overrides:/_dependency_overrides:/g' '{}' ';'
	@$(DART_BIN) pub global run pana --no-warning --source path barcode
	@find barcode -name pubspec.yaml -exec sed -i -e 's/^_dependency_overrides:/dependency_overrides:/g' '{}' ';'

analyze-flutter: .pana
	@find flutter -name pubspec.yaml -exec sed -i -e 's/^dependency_overrides:/_dependency_overrides:/g' '{}' ';'
	rm -f flutter/pubspec.lock
	@$(FLUTTER_BIN) pub global run pana --no-warning --source path flutter
	@find flutter -name pubspec.yaml -exec sed -i -e 's/^_dependency_overrides:/dependency_overrides:/g' '{}' ';'

analyze-image: .pana
	@find image -name pubspec.yaml -exec sed -i -e 's/^dependency_overrides:/_dependency_overrides:/g' '{}' ';'
	@$(DART_BIN) pub global run pana --no-warning --source path image
	@find image -name pubspec.yaml -exec sed -i -e 's/^_dependency_overrides:/dependency_overrides:/g' '{}' ';'

analyze: analyze-barcode analyze-flutter analyze-image

image/lib/src/pubspec.dart: image/pubspec.yaml
	cd image; $(DART_BIN) run pubspec_extract -s "../$<" -d "../$@"

.dartfix:
	which dartfix || $(DART_BIN) pub global activate dartfix
	touch $@

fix: .dartfix
	cd barcode; $(DART_BIN) pub get
	cd barcode; $(DART_BIN) pub global run dartfix --overwrite .

barcodes: .coverage
	cd barcode; $(DART_BIN) pub global run coverage:collect_coverage --port=$(COV_PORT) -o coverage.json --resume-isolates --wait-paused &\
	$(DART_BIN) --enable-asserts --disable-service-auth-codes --enable-vm-service=$(COV_PORT) --pause-isolates-on-exit example/main.dart
	cd barcode; $(DART_BIN) pub global run coverage:format_coverage --packages=.dart_tool/package_config.json -i coverage.json --report-on lib --lcov --out ../lcov-example.info
	mv -f barcode/*.svg img/

icons:
	$(DART_BIN) image/bin/barcode.dart -t CodeEAN2 -w 16 -h 16 --no-text -o flutter/example/web/favicon.png 42
	$(DART_BIN) image/bin/barcode.dart -t QrCode -w 192 -h 192 --no-text -o flutter/example/web/icons/Icon-192.png Barcode
	$(DART_BIN) image/bin/barcode.dart -t QrCode -w 512 -h 512 --no-text -o flutter/example/web/icons/Icon-512.png https://davbfr.github.io/dart_barcode

maps: build_maps.py
	python3 build_maps.py > barcode/lib/src/barcode_maps.dart
	dartfmt -w --fix barcode/lib/src/barcode_maps.dart

gh-pages:
	test -z "$(shell git status --porcelain)"
	cd demo; $(FLUTTER_BIN) build web --release --dart-define=FLUTTER_WEB_USE_SKIA=true
	git checkout gh-pages
	cp -rf demo/build/web/* .

get:
	cd barcode; $(DART_BIN) pub get
	cd flutter; $(FLUTTER_BIN) packages get
	cd image; $(DART_BIN) pub get

.PHONY: test format format-dart clean publish analyze
