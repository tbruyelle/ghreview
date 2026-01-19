package pr

import (
	"encoding/json"
	"fmt"

	"github.com/google/go-github/v57/github"
	ghclient "github.com/tbruyelle/ghreview/github"
)

// CommentsParams represents parameters for getting PR comments
type CommentsParams struct {
	Repo   string `json:"repo"`
	Number int    `json:"number"`
}

// Comment represents a review comment on a PR
type Comment struct {
	ID        int64  `json:"id"`
	Path      string `json:"path"`
	Line      int    `json:"line"`
	Body      string `json:"body"`
	Author    string `json:"author"`
	CreatedAt string `json:"created_at"`
	UpdatedAt string `json:"updated_at"`
	URL       string `json:"url"`
	InReplyTo int64  `json:"in_reply_to,omitempty"`
}

// CommentsResult represents the comments on a PR
type CommentsResult struct {
	Number         int       `json:"number"`
	ReviewComments []Comment `json:"review_comments"`
	IssueComments  []Comment `json:"issue_comments"`
}

// Comments returns comments for a specific PR
func (s *Service) Comments(params json.RawMessage) (interface{}, error) {
	var p CommentsParams
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, fmt.Errorf("invalid params: %w", err)
	}

	owner, repo, err := ghclient.ParseRepo(p.Repo)
	if err != nil {
		return nil, err
	}

	// Get review comments (inline comments on code)
	reviewOpts := &github.PullRequestListCommentsOptions{
		ListOptions: github.ListOptions{PerPage: 100},
	}
	reviewComments, _, err := s.client.PullRequests.ListComments(s.client.Context(), owner, repo, p.Number, reviewOpts)
	if err != nil {
		return nil, fmt.Errorf("failed to list review comments: %w", err)
	}

	// Get issue comments (general PR comments)
	issueOpts := &github.IssueListCommentsOptions{
		ListOptions: github.ListOptions{PerPage: 100},
	}
	issueComments, _, err := s.client.Issues.ListComments(s.client.Context(), owner, repo, p.Number, issueOpts)
	if err != nil {
		return nil, fmt.Errorf("failed to list issue comments: %w", err)
	}

	result := CommentsResult{
		Number:         p.Number,
		ReviewComments: make([]Comment, 0, len(reviewComments)),
		IssueComments:  make([]Comment, 0, len(issueComments)),
	}

	for _, c := range reviewComments {
		comment := Comment{
			ID:        c.GetID(),
			Path:      c.GetPath(),
			Line:      c.GetLine(),
			Body:      c.GetBody(),
			Author:    c.GetUser().GetLogin(),
			CreatedAt: c.GetCreatedAt().Format("2006-01-02 15:04"),
			UpdatedAt: c.GetUpdatedAt().Format("2006-01-02 15:04"),
			URL:       c.GetHTMLURL(),
			InReplyTo: c.GetInReplyTo(),
		}
		result.ReviewComments = append(result.ReviewComments, comment)
	}

	for _, c := range issueComments {
		comment := Comment{
			ID:        c.GetID(),
			Body:      c.GetBody(),
			Author:    c.GetUser().GetLogin(),
			CreatedAt: c.GetCreatedAt().Format("2006-01-02 15:04"),
			UpdatedAt: c.GetUpdatedAt().Format("2006-01-02 15:04"),
			URL:       c.GetHTMLURL(),
		}
		result.IssueComments = append(result.IssueComments, comment)
	}

	return result, nil
}

// AddCommentParams represents parameters for adding a review comment
type AddCommentParams struct {
	Repo   string `json:"repo"`
	Number int    `json:"number"`
	Path   string `json:"path"`
	Line   int    `json:"line"`
	Body   string `json:"body"`
	Side   string `json:"side,omitempty"` // LEFT or RIGHT (default)
}

// AddComment adds a review comment to a specific line in a PR
func (s *Service) AddComment(params json.RawMessage) (interface{}, error) {
	var p AddCommentParams
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, fmt.Errorf("invalid params: %w", err)
	}

	owner, repo, err := ghclient.ParseRepo(p.Repo)
	if err != nil {
		return nil, err
	}

	// Get the PR to find the latest commit SHA
	pr, _, err := s.client.PullRequests.Get(s.client.Context(), owner, repo, p.Number)
	if err != nil {
		return nil, fmt.Errorf("failed to get PR: %w", err)
	}

	side := p.Side
	if side == "" {
		side = "RIGHT"
	}

	comment := &github.PullRequestComment{
		Body:     github.String(p.Body),
		Path:     github.String(p.Path),
		CommitID: pr.Head.SHA,
		Line:     github.Int(p.Line),
		Side:     github.String(side),
	}

	created, _, err := s.client.PullRequests.CreateComment(s.client.Context(), owner, repo, p.Number, comment)
	if err != nil {
		return nil, fmt.Errorf("failed to create comment: %w", err)
	}

	return Comment{
		ID:        created.GetID(),
		Path:      created.GetPath(),
		Line:      created.GetLine(),
		Body:      created.GetBody(),
		Author:    created.GetUser().GetLogin(),
		CreatedAt: created.GetCreatedAt().Format("2006-01-02 15:04"),
		URL:       created.GetHTMLURL(),
	}, nil
}
