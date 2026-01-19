package pr

import "github.com/tbruyelle/ghreview/github"

// Service provides PR-related operations
type Service struct {
	client *github.Client
}

// NewService creates a new PR service
func NewService(client *github.Client) *Service {
	return &Service{client: client}
}
