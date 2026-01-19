package pr

import (
	"encoding/json"
	"fmt"

	"github.com/google/go-github/v57/github"
	ghclient "github.com/tbruyelle/ghreview/github"
)

// SubmitReviewParams represents parameters for submitting a review
type SubmitReviewParams struct {
	Repo   string `json:"repo"`
	Number int    `json:"number"`
	Event  string `json:"event"` // APPROVE, REQUEST_CHANGES, COMMENT
	Body   string `json:"body"`
}

// ReviewResult represents the result of submitting a review
type ReviewResult struct {
	ID        int64  `json:"id"`
	State     string `json:"state"`
	Body      string `json:"body"`
	Author    string `json:"author"`
	CreatedAt string `json:"created_at"`
	URL       string `json:"url"`
}

// SubmitReview submits a review for a PR
func (s *Service) SubmitReview(params json.RawMessage) (interface{}, error) {
	var p SubmitReviewParams
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, fmt.Errorf("invalid params: %w", err)
	}

	owner, repo, err := ghclient.ParseRepo(p.Repo)
	if err != nil {
		return nil, err
	}

	// Validate event type
	switch p.Event {
	case "APPROVE", "REQUEST_CHANGES", "COMMENT":
		// valid
	default:
		return nil, fmt.Errorf("invalid event type: %s (must be APPROVE, REQUEST_CHANGES, or COMMENT)", p.Event)
	}

	review := &github.PullRequestReviewRequest{
		Event: github.String(p.Event),
		Body:  github.String(p.Body),
	}

	created, _, err := s.client.PullRequests.CreateReview(s.client.Context(), owner, repo, p.Number, review)
	if err != nil {
		return nil, fmt.Errorf("failed to submit review: %w", err)
	}

	return ReviewResult{
		ID:        created.GetID(),
		State:     created.GetState(),
		Body:      created.GetBody(),
		Author:    created.GetUser().GetLogin(),
		CreatedAt: created.GetSubmittedAt().Format("2006-01-02 15:04"),
		URL:       created.GetHTMLURL(),
	}, nil
}
