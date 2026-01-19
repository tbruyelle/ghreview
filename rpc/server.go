package rpc

import (
	"encoding/json"
	"fmt"

	"github.com/tbruyelle/ghreview/github"
	"github.com/tbruyelle/ghreview/pr"
)

// Request represents a JSON-RPC request
type Request struct {
	ID     int             `json:"id"`
	Method string          `json:"method"`
	Params json.RawMessage `json:"params"`
}

// Response represents a JSON-RPC response
type Response struct {
	ID     int         `json:"id"`
	Result interface{} `json:"result,omitempty"`
	Error  *Error      `json:"error,omitempty"`
}

// Error represents a JSON-RPC error
type Error struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

// Server handles JSON-RPC requests
type Server struct {
	client   *github.Client
	handlers map[string]Handler
}

// Handler is a function that handles a specific RPC method
type Handler func(params json.RawMessage) (interface{}, error)

// NewServer creates a new RPC server
func NewServer(client *github.Client) *Server {
	s := &Server{
		client:   client,
		handlers: make(map[string]Handler),
	}
	s.registerHandlers()
	return s
}

func (s *Server) registerHandlers() {
	prService := pr.NewService(s.client)

	s.handlers["pr/list"] = prService.List
	s.handlers["pr/diff"] = prService.Diff
	s.handlers["pr/comments"] = prService.Comments
	s.handlers["pr/add_comment"] = prService.AddComment
	s.handlers["pr/submit_review"] = prService.SubmitReview
}

// Handle processes a JSON-RPC request and returns a response
func (s *Server) Handle(data []byte) Response {
	var req Request
	if err := json.Unmarshal(data, &req); err != nil {
		return Response{
			Error: &Error{
				Code:    -32700,
				Message: fmt.Sprintf("Parse error: %v", err),
			},
		}
	}

	handler, ok := s.handlers[req.Method]
	if !ok {
		return Response{
			ID: req.ID,
			Error: &Error{
				Code:    -32601,
				Message: fmt.Sprintf("Method not found: %s", req.Method),
			},
		}
	}

	result, err := handler(req.Params)
	if err != nil {
		return Response{
			ID: req.ID,
			Error: &Error{
				Code:    -32000,
				Message: err.Error(),
			},
		}
	}

	return Response{
		ID:     req.ID,
		Result: result,
	}
}
