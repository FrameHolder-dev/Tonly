package service

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"strconv"
	"strings"

	"github.com/FrameHolder-dev/Tonly/backend/internal/model"
)

type Parser struct {
	api *TonAPI
}

func NewParser() *Parser {
	return &Parser{
		api: NewTonAPI(),
	}
}

func (p *Parser) GetWalletOverview(ctx context.Context, address string) (*model.WalletOverview, error) {
	accountData, err := p.api.GetAccount(ctx, address)
	if err != nil {
		return nil, fmt.Errorf("account: %w", err)
	}

	var account struct {
		Balance int64  `json:"balance"`
		Status  string `json:"status"`
	}
	json.Unmarshal(accountData, &account)

	tonBalance := float64(account.Balance) / 1e9

	ratesData, err := p.api.GetRates(ctx, "ton", "usd")
	tonPrice := 0.0
	if err == nil {
		var rates struct {
			Rates map[string]struct {
				Prices map[string]float64 `json:"prices"`
			} `json:"rates"`
		}
		if json.Unmarshal(ratesData, &rates) == nil {
			if tonRates, ok := rates.Rates["TON"]; ok {
				tonPrice = tonRates.Prices["USD"]
			}
		}
	}

	jettons, err := p.GetJettons(ctx, address)
	if err != nil {
		jettons = []model.JettonBalance{}
	}

	tonUSD := tonBalance * tonPrice
	totalUSD := tonUSD
	for _, j := range jettons {
		totalUSD += j.USDValue
	}

	return &model.WalletOverview{
		Address:    address,
		BalanceTON: fmt.Sprintf("%.4f", tonBalance),
		BalanceUSD: math.Round(tonUSD*100) / 100,
		TONPrice:   tonPrice,
		Jettons:    jettons,
		TotalUSD:   math.Round(totalUSD*100) / 100,
	}, nil
}

func (p *Parser) GetJettons(ctx context.Context, address string) ([]model.JettonBalance, error) {
	data, err := p.api.GetJettons(ctx, address)
	if err != nil {
		return nil, err
	}

	var response struct {
		Balances []struct {
			Balance  string `json:"balance"`
			WalletAddress struct {
				Address string `json:"address"`
			} `json:"wallet_address"`
			Jetton struct {
				Address    string `json:"address"`
				Name       string `json:"name"`
				Symbol     string `json:"symbol"`
				Decimals   int    `json:"decimals"`
				Image      string `json:"image"`
				Verification string `json:"verification"`
			} `json:"jetton"`
			Price struct {
				Prices struct {
					USD float64 `json:"USD"`
				} `json:"prices"`
			} `json:"price"`
		} `json:"balances"`
	}

	if err := json.Unmarshal(data, &response); err != nil {
		return nil, err
	}

	result := make([]model.JettonBalance, 0, len(response.Balances))
	for _, b := range response.Balances {
		balance, _ := strconv.ParseFloat(b.Balance, 64)
		decimals := b.Jetton.Decimals
		if decimals > 0 {
			balance = balance / math.Pow(10, float64(decimals))
		}

		usdPrice := b.Price.Prices.USD
		usdValue := math.Round(balance*usdPrice*100) / 100

		result = append(result, model.JettonBalance{
			Address:  b.Jetton.Address,
			Name:     b.Jetton.Name,
			Symbol:   b.Jetton.Symbol,
			Decimals: decimals,
			Balance:  fmt.Sprintf("%.6f", balance),
			ImageURL: b.Jetton.Image,
			USDPrice: usdPrice,
			USDValue: usdValue,
			Verified: b.Jetton.Verification == "whitelist",
		})
	}

	return result, nil
}

func (p *Parser) GetNFTs(ctx context.Context, address string) ([]model.NFTItem, error) {
	data, err := p.api.GetNFTs(ctx, address)
	if err != nil {
		return nil, err
	}

	var response struct {
		NFTItems []struct {
			Address  string `json:"address"`
			DNS      string `json:"dns"`
			Metadata struct {
				Name        string `json:"name"`
				Description string `json:"description"`
				Image       string `json:"image"`
			} `json:"metadata"`
			Previews []struct {
				Resolution string `json:"resolution"`
				URL        string `json:"url"`
			} `json:"previews"`
			Collection struct {
				Address string `json:"address"`
				Name    string `json:"name"`
			} `json:"collection"`
			Trust string `json:"trust"`
		} `json:"nft_items"`
	}

	if err := json.Unmarshal(data, &response); err != nil {
		return nil, err
	}

	result := make([]model.NFTItem, 0, len(response.NFTItems))
	for _, n := range response.NFTItems {
		imageURL := n.Metadata.Image
		if imageURL == "" {
			for _, p := range n.Previews {
				if p.Resolution == "500x500" || p.Resolution == "1500x1500" {
					imageURL = p.URL
					break
				}
			}
			if imageURL == "" && len(n.Previews) > 0 {
				imageURL = n.Previews[len(n.Previews)-1].URL
			}
		}

		nftType := "nft"
		collName := n.Collection.Name
		switch {
		case collName == "TON DNS Domains":
			nftType = "dns"
		case collName == "Anonymous Telegram Numbers":
			nftType = "anonymous_number"
		case collName == "Telegram Usernames":
			nftType = "username"
		case strings.Contains(strings.ToLower(collName), "gift"):
			nftType = "gift"
		}

		result = append(result, model.NFTItem{
			Address:        n.Address,
			Name:           n.Metadata.Name,
			Description:    n.Metadata.Description,
			ImageURL:       imageURL,
			CollectionName: collName,
			CollectionAddr: n.Collection.Address,
			Verified:       n.Trust == "whitelist",
			DNS:            n.DNS,
			NFTType:        nftType,
		})
	}

	return result, nil
}
