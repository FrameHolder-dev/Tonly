package service

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/FrameHolder-dev/Tonly/backend/internal/config"
)

type TonAPI struct {
	baseURL string
	apiKey  string
	client  *http.Client
}

func NewTonAPI() *TonAPI {
	cfg := config.Load()
	return &TonAPI{
		baseURL: cfg.TonAPIV3,
		apiKey:  cfg.TonAPIKey,
		client: &http.Client{
			Timeout: 15 * time.Second,
		},
	}
}

func (s *TonAPI) get(ctx context.Context, path string) ([]byte, error) {
	url := s.baseURL + path

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}

	if s.apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+s.apiKey)
	}

	resp, err := s.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("tonapi: status %d", resp.StatusCode)
	}

	return io.ReadAll(resp.Body)
}

func (s *TonAPI) GetAccount(ctx context.Context, address string) (json.RawMessage, error) {
	data, err := s.get(ctx, "/accounts/"+address)
	if err != nil {
		return nil, err
	}
	return json.RawMessage(data), nil
}

func (s *TonAPI) GetSeqno(ctx context.Context, address string) (int, error) {
	data, err := s.get(ctx, "/wallet/"+address+"/seqno")
	if err != nil {
		return 0, err
	}
	var result struct {
		Seqno int `json:"seqno"`
	}
	if err := json.Unmarshal(data, &result); err != nil {
		return 0, err
	}
	return result.Seqno, nil
}

func (s *TonAPI) GetJettons(ctx context.Context, address string) (json.RawMessage, error) {
	data, err := s.get(ctx, "/accounts/"+address+"/jettons")
	if err != nil {
		return nil, err
	}
	return json.RawMessage(data), nil
}

func (s *TonAPI) GetNFTs(ctx context.Context, address string) (json.RawMessage, error) {
	data, err := s.get(ctx, "/accounts/"+address+"/nfts")
	if err != nil {
		return nil, err
	}
	return json.RawMessage(data), nil
}

func (s *TonAPI) GetEvents(ctx context.Context, address string, limit string) (json.RawMessage, error) {
	data, err := s.get(ctx, "/accounts/"+address+"/events?limit="+limit)
	if err != nil {
		return nil, err
	}
	return json.RawMessage(data), nil
}

func (s *TonAPI) GetRates(ctx context.Context, tokens string, currencies string) (json.RawMessage, error) {
	data, err := s.get(ctx, "/rates?tokens="+tokens+"&currencies="+currencies)
	if err != nil {
		return nil, err
	}
	return json.RawMessage(data), nil
}

func (s *TonAPI) GetChart(ctx context.Context, token string, currency string, period string) (json.RawMessage, error) {
	data, err := s.get(ctx, "/rates/chart?token="+token+"&currency="+currency+"&period="+period)
	if err != nil {
		return nil, err
	}
	return json.RawMessage(data), nil
}

func (s *TonAPI) ResolveDomain(ctx context.Context, domain string) (json.RawMessage, error) {
	data, err := s.get(ctx, "/dns/"+domain+"/resolve")
	if err != nil {
		return nil, err
	}
	return json.RawMessage(data), nil
}

func (s *TonAPI) GetStakingPools(ctx context.Context, address string) (json.RawMessage, error) {
	data, err := s.get(ctx, "/staking/nominator/"+address+"/pools")
	if err != nil {
		return nil, err
	}
	return json.RawMessage(data), nil
}

func (s *TonAPI) EstimateFee(ctx context.Context, address string) (json.RawMessage, error) {
	data, err := s.get(ctx, "/accounts/"+address)
	if err != nil {
		return nil, err
	}
	return json.RawMessage(data), nil
}
