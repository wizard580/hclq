DIST          := $(shell mkdir -p dist && printf dist)
TOOLS         := tools/bin
SOURCE         = $(shell find . -name '*.go')
MODULE         = $(shell head -n1 < go.mod | awk '{print $$2}')
# Version and linker flags
# This will return either the current tag, branch, or commit hash of this repo.
VERSION        = $(shell echo $$(ver=$$(git tag -l --points-at HEAD) && [ -z $$ver ] && ver=$$(git describe --always --dirty --all | sed 's/heads\///'); printf '0.0.0-%s' "$$ver"))
LDFLAGS        = -s -w -X main.version=${VERSION}
IS_PUBLISH     = $(APPVEYOR_REPO_TAG)
BUILD_CMD      = go build -mod=vendor -ldflags="${LDFLAGS}" -o "$@" $(MODULE)
# Build tools
GHR             := github.com/tcnksm/ghr
GO_JUNIT_REPORT := github.com/jstemmer/go-junit-report
PIGEON          := $(TOOLS)/pigeon
PIGEON_MODULE   := github.com/mna/pigeon
PIGEON_SRC       = $(shell find vendor/$(PIGEON_MODULE) -type f -name '*.go')
GOIMPORTS       := $(TOOLS)/goimports
GOIMPORTS_MODULE := golang.org/x/tools/cmd/goimports
GOIMPORTS_SRC   = $(shell find vendor/$(GOIMPORTS_MODULE) -type f -name '*.go')

default: build test README.md

build: $(DIST)/hclq

$(DIST)/hclq: $(SOURCE)
	$(BUILD_CMD)

queryast/query_peg.go: queryast/query.peg | peg-prereqs
	$(PIGEON) $< | $(GOIMPORTS) > $@


clean:
	rm -rf $(DIST) $(TOOLS)

$(DIST): $(DIST)/hclq-%
	cd $(DIST) && shasum -a 256 hclq-* > hclq-shasums

$(DIST)/hclq-darwin-amd64:
	export GOOS=darwin  GOARCH=amd64; $(BUILD_CMD) -o "$@"

$(DIST)/hclq-freebsd-386:
	export GOOS=freebsd GOARCH=386  ; $(BUILD_CMD) -o "$@"

$(DIST)/hclq-freebsd-amd64:
	export GOOS=freebsd GOARCH=amd64; $(BUILD_CMD) -o "$@"

$(DIST)/hclq-freebsd-arm:
	export GOOS=freebsd GOARCH=arm  ; $(BUILD_CMD) -o "$@"

$(DIST)/hclq-linux-amd64:
	export GOOS=linux   GOARCH=amd64; $(BUILD_CMD) -o "$@"

$(DIST)/hclq-linux-arm:
	export GOOS=linux   GOARCH=arm  ; $(BUILD_CMD) -o "$@"

$(DIST)/hclq-openbsd-amd64:
	export GOOS=openbsd GOARCH=386  ; $(BUILD_CMD) -o "$@"

$(DIST)/hclq-solaris-amd64:
	export GOOS=solaris GOARCH=amd64; $(BUILD_CMD) -o "$@"

$(DIST)/hclq-windows-amd64:
	export GOOS=windows GOARCH=amd64; $(BUILD_CMD) -o "$@"

install:
	go install -mod=vendor -ldflags="${LDFLAGS}"

# GitHub Release Tool
$(GHR):
	go install -mod=vendor $(GHR)

# Translates Go test results to JUnit XML
$(GO_JUNIT_REPORT):
	go install -mod=vendor $(GO_JUNIT_REPORT)

$(PIGEON): $(PIGEON_SRC)
	go build -o $(PIGEON) -mod=vendor $(PIGEON_MODULE)

$(GOIMPORTS): $(GOIMPORTS_SRC)
	go build -o $(GOIMPORTS) -mod=vendor $(GOIMPORTS_MODULE)

peg-prereqs: $(PIGEON) $(GOIMPORTS)

publish: $(GHR) test dist
	[ -n "$(IS_PUBLISH)" ] && ghr -replace -delete -u "$$GITHUB_USER" ${VERSION} dist/

readme: README.md
README.md: README.md.rb
	@if [ ! -f .git/hooks/pre-commit ]; then printf "Missing pre-commit hook for readme, be sure to copy it from hclq-pages repo"; exit 1; fi
	erb README.md.rb > README.md

test: $(GO_JUNIT_REPORT) build
	@mkdir -p test
	HCLQ_BIN=dist/hclq go test -mod=vendor -v "./..." | tee /dev/tty | go-junit-report > test/TEST.xml

fmt:
	go fmt ./...

.PHONY: clean install publish test