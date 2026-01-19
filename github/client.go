package github

import (
	"context"
	"fmt"
	"os/exec"
	"strings"

	"github.com/google/go-github/v57/github"
	"golang.org/x/oauth2"
)

// Client wraps the GitHub API client
type Client struct {
	*github.Client
	ctx context.Context
}

// NewClient creates a new GitHub client using the gh CLI for authentication
func NewClient() (*Client, error) {
	token, err := getGHToken()
	if err != nil {
		return nil, fmt.Errorf("failed to get GitHub token: %w", err)
	}

	ctx := context.Background()
	ts := oauth2.StaticTokenSource(
		&oauth2.Token{AccessToken: token},
	)
	tc := oauth2.NewClient(ctx, ts)

	client := github.NewClient(tc)

	return &Client{
		Client: client,
		ctx:    ctx,
	}, nil
}

// getGHToken retrieves the GitHub token using the gh CLI
func getGHToken() (string, error) {
	cmd := exec.Command("gh", "auth", "token")
	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("gh auth token failed: %w (is gh CLI installed and authenticated?)", err)
	}
	return strings.TrimSpace(string(output)), nil
}

// Context returns the client's context
func (c *Client) Context() context.Context {
	return c.ctx
}

// ParseRepo splits "owner/repo" into owner and repo
func ParseRepo(repo string) (owner, name string, err error) {
	parts := strings.Split(repo, "/")
	if len(parts) != 2 {
		return "", "", fmt.Errorf("invalid repo format: %q (expected owner/repo)", repo)
	}
	return parts[0], parts[1], nil
}
