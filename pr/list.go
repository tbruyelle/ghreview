package pr

import (
	"encoding/json"
	"fmt"

	"github.com/google/go-github/v57/github"
	ghclient "github.com/tbruyelle/ghreview/github"
)

// ListParams represents parameters for listing PRs
type ListParams struct {
	Repo  string `json:"repo"`
	State string `json:"state"` // open, closed, all
}

// PRItem represents a PR in the list
type PRItem struct {
	Number    int    `json:"number"`
	Title     string `json:"title"`
	Author    string `json:"author"`
	State     string `json:"state"`
	CreatedAt string `json:"created_at"`
	UpdatedAt string `json:"updated_at"`
	URL       string `json:"url"`
	Draft     bool   `json:"draft"`
}

// List returns a list of PRs for the given repository
func (s *Service) List(params json.RawMessage) (interface{}, error) {
	var p ListParams
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, fmt.Errorf("invalid params: %w", err)
	}

	owner, repo, err := ghclient.ParseRepo(p.Repo)
	if err != nil {
		return nil, err
	}

	state := p.State
	if state == "" {
		state = "open"
	}

	opts := &github.PullRequestListOptions{
		State: state,
		ListOptions: github.ListOptions{
			PerPage: 100,
		},
	}

	prs, _, err := s.client.PullRequests.List(s.client.Context(), owner, repo, opts)
	if err != nil {
		return nil, fmt.Errorf("failed to list PRs: %w", err)
	}

	result := make([]PRItem, 0, len(prs))
	for _, pr := range prs {
		item := PRItem{
			Number:    pr.GetNumber(),
			Title:     pr.GetTitle(),
			Author:    pr.GetUser().GetLogin(),
			State:     pr.GetState(),
			CreatedAt: pr.GetCreatedAt().Format("2006-01-02"),
			UpdatedAt: pr.GetUpdatedAt().Format("2006-01-02"),
			URL:       pr.GetHTMLURL(),
			Draft:     pr.GetDraft(),
		}
		result = append(result, item)
	}

	return result, nil
}
