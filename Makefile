.PHONY: build clean test install

BINARY_NAME=ghreview

build:
	go build -o bin/$(BINARY_NAME) ./cmd/ghreview

clean:
	rm -rf bin/
	go clean

test:
	go test -v ./...

install:
	go install ./cmd/ghreview
	@echo "Binary installed to \$$GOPATH/bin/ghreview"
	@echo ""
	@echo "Add the following to your .vimrc:"
	@echo "  set runtimepath+=$(PWD)"
	@echo ""
	@echo "Or create a symlink:"
	@echo "  ln -s $(PWD) ~/.vim/pack/plugins/start/ghreview"

deps:
	go mod tidy

# Test the RPC manually
test-rpc: build
	@echo '{"id":1,"method":"pr/list","params":{"repo":"$(REPO)","state":"open"}}' | ./bin/$(BINARY_NAME)
