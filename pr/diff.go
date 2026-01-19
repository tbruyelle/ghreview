package pr

import (
	"encoding/json"
	"fmt"

	"github.com/google/go-github/v57/github"
	ghclient "github.com/tbruyelle/ghreview/github"
)

// DiffParams represents parameters for getting a PR diff
type DiffParams struct {
	Repo   string `json:"repo"`
	Number int    `json:"number"`
}

// FileChange represents a changed file in a PR
type FileChange struct {
	Filename  string `json:"filename"`
	Status    string `json:"status"` // added, removed, modified, renamed
	Additions int    `json:"additions"`
	Deletions int    `json:"deletions"`
	Patch     string `json:"patch"`
}

// DiffResult represents the diff result for a PR
type DiffResult struct {
	Number      int          `json:"number"`
	Title       string       `json:"title"`
	BaseBranch  string       `json:"base_branch"`
	HeadBranch  string       `json:"head_branch"`
	Files       []FileChange `json:"files"`
	TotalFiles  int          `json:"total_files"`
	Additions   int          `json:"additions"`
	Deletions   int          `json:"deletions"`
	Commits     int          `json:"commits"`
	Description string       `json:"description"`
}

// Diff returns the diff for a specific PR
func (s *Service) Diff(params json.RawMessage) (interface{}, error) {
	var p DiffParams
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, fmt.Errorf("invalid params: %w", err)
	}

	owner, repo, err := ghclient.ParseRepo(p.Repo)
	if err != nil {
		return nil, err
	}

	// Get PR details
	pr, _, err := s.client.PullRequests.Get(s.client.Context(), owner, repo, p.Number)
	if err != nil {
		return nil, fmt.Errorf("failed to get PR: %w", err)
	}

	// Get files changed
	opts := &github.ListOptions{PerPage: 100}
	files, _, err := s.client.PullRequests.ListFiles(s.client.Context(), owner, repo, p.Number, opts)
	if err != nil {
		return nil, fmt.Errorf("failed to list PR files: %w", err)
	}

	changes := make([]FileChange, 0, len(files))
	for _, f := range files {
		change := FileChange{
			Filename:  f.GetFilename(),
			Status:    f.GetStatus(),
			Additions: f.GetAdditions(),
			Deletions: f.GetDeletions(),
			Patch:     f.GetPatch(),
		}
		changes = append(changes, change)
	}

	result := DiffResult{
		Number:      pr.GetNumber(),
		Title:       pr.GetTitle(),
		BaseBranch:  pr.GetBase().GetRef(),
		HeadBranch:  pr.GetHead().GetRef(),
		Files:       changes,
		TotalFiles:  len(files),
		Additions:   pr.GetAdditions(),
		Deletions:   pr.GetDeletions(),
		Commits:     pr.GetCommits(),
		Description: pr.GetBody(),
	}

	return result, nil
}
