package service

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/FrameHolder-dev/Tonly/backend/internal/config"
)

type TON struct {
	baseURL string
	client  *http.Client
}

func NewTON() *TON {
	cfg := config.Load()
	return &TON{
		baseURL: cfg.TONAPIBase,
		client: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

func (s *TON) GetBalance(ctx context.Context, address string) (string, error) {
	url := fmt.Sprintf("%s/getAddressBalance?address=%s", s.baseURL, address)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return "", err
	}

	resp, err := s.client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	var result struct {
		OK     bool   `json:"ok"`
		Result string `json:"result"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", err
	}

	if !result.OK {
		return "", fmt.Errorf("ton api error")
	}

	return result.Result, nil
}

func (s *TON) GetTransactions(ctx context.Context, address, limit string) (json.RawMessage, error) {
	url := fmt.Sprintf("%s/getTransactions?address=%s&limit=%s", s.baseURL, address, limit)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}

	resp, err := s.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var result struct {
		OK     bool            `json:"ok"`
		Result json.RawMessage `json:"result"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}

	if !result.OK {
		return nil, fmt.Errorf("ton api error")
	}

	return result.Result, nil
}
