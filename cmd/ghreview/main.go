package main

import (
	"bufio"
	"encoding/json"
	"log"
	"os"

	"github.com/tbruyelle/ghreview/github"
	"github.com/tbruyelle/ghreview/rpc"
)

func main() {
	// Set up logging to stderr (stdout is for JSON-RPC)
	log.SetOutput(os.Stderr)
	log.SetPrefix("[ghreview] ")

	// Initialize GitHub client
	client, err := github.NewClient()
	if err != nil {
		log.Fatalf("Failed to initialize GitHub client: %v", err)
	}

	// Create RPC server
	server := rpc.NewServer(client)

	// Read JSON-RPC requests from stdin, write responses to stdout
	scanner := bufio.NewScanner(os.Stdin)
	encoder := json.NewEncoder(os.Stdout)

	for scanner.Scan() {
		line := scanner.Bytes()
		if len(line) == 0 {
			continue
		}

		response := server.Handle(line)
		if err := encoder.Encode(response); err != nil {
			log.Printf("Failed to encode response: %v", err)
		}
	}

	if err := scanner.Err(); err != nil {
		log.Fatalf("Error reading stdin: %v", err)
	}
}
