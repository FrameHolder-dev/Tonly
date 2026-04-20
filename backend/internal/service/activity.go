package service

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"strconv"
	"strings"
)

type ActivityItem struct {
	ID         string  `json:"id"`
	Hash       string  `json:"hash"`
	Timestamp  int64   `json:"timestamp"`
	Kind       string  `json:"kind"`
	Status     string  `json:"status"`
	IsIncoming bool    `json:"is_incoming"`
	From       string  `json:"from"`
	To         string  `json:"to"`
	Amount     float64 `json:"amount"`
	Symbol     string  `json:"symbol"`
	IconURL    string  `json:"icon_url,omitempty"`
	Comment    string  `json:"comment,omitempty"`
	USDValue   float64 `json:"usd_value,omitempty"`
}

func (p *Parser) GetActivity(ctx context.Context, address string, limit string) ([]ActivityItem, error) {
	data, err := p.api.GetEvents(ctx, address, limit)
	if err != nil {
		return nil, err
	}

	var response struct {
		Events []struct {
			EventID   string `json:"event_id"`
			Timestamp int64  `json:"timestamp"`
			Actions   []struct {
				Type   string `json:"type"`
				Status string `json:"status"`

				TonTransfer *struct {
					Sender    struct{ Address string } `json:"sender"`
					Recipient struct{ Address string } `json:"recipient"`
					Amount    int64                    `json:"amount"`
					Comment   string                   `json:"comment"`
				} `json:"TonTransfer"`

				JettonTransfer *struct {
					Sender    *struct{ Address string } `json:"sender"`
					Recipient *struct{ Address string } `json:"recipient"`
					Amount    string                    `json:"amount"`
					Comment   string                    `json:"comment"`
					Jetton    struct {
						Address  string `json:"address"`
						Name     string `json:"name"`
						Symbol   string `json:"symbol"`
						Decimals int    `json:"decimals"`
						Image    string `json:"image"`
					} `json:"jetton"`
				} `json:"JettonTransfer"`

				JettonSwap *struct {
					DEX        string `json:"dex"`
					Sender     struct{ Address string } `json:"sender"`
					Amount1In  string `json:"amount_in"`
					AmountOut  string `json:"amount_out"`
					JettonMasterIn *struct {
						Symbol   string `json:"symbol"`
						Decimals int    `json:"decimals"`
						Image    string `json:"image"`
					} `json:"jetton_master_in"`
					JettonMasterOut *struct {
						Symbol   string `json:"symbol"`
						Decimals int    `json:"decimals"`
						Image    string `json:"image"`
					} `json:"jetton_master_out"`
					TonIn  int64 `json:"ton_in"`
					TonOut int64 `json:"ton_out"`
				} `json:"JettonSwap"`

				NftItemTransfer *struct {
					Sender    *struct{ Address string } `json:"sender"`
					Recipient *struct{ Address string } `json:"recipient"`
					NFT       string                    `json:"nft"`
					Comment   string                    `json:"comment"`
				} `json:"NftItemTransfer"`

				ContractDeploy *struct {
					Address string `json:"address"`
				} `json:"ContractDeploy"`

				Subscribe *struct {
					Subscriber  struct{ Address string } `json:"subscriber"`
					Beneficiary struct{ Address string } `json:"beneficiary"`
					Amount      int64                    `json:"amount"`
				} `json:"Subscribe"`

				UnSubscribe *struct {
					Subscriber  struct{ Address string } `json:"subscriber"`
					Beneficiary struct{ Address string } `json:"beneficiary"`
					Amount      int64                    `json:"amount"`
				} `json:"UnSubscribe"`

				DomainRenew *struct {
					Domain         string `json:"domain"`
					ContractAddress string `json:"contract_address"`
				} `json:"DomainRenew"`

				AuctionBid *struct {
					Amount *struct {
						Value       string `json:"value"`
						TokenName   string `json:"token_name"`
					} `json:"amount"`
					NFT *struct {
						Address string `json:"address"`
						Metadata struct {
							Name  string `json:"name"`
							Image string `json:"image"`
						} `json:"metadata"`
					} `json:"nft"`
					Bidder struct{ Address string } `json:"bidder"`
				} `json:"AuctionBid"`

				DepositStake *struct {
					Amount int64                    `json:"amount"`
					Staker struct{ Address string } `json:"staker"`
					Pool   struct {
						Address       string `json:"address"`
						Name          string `json:"name"`
						Implementation string `json:"implementation"`
					} `json:"pool"`
				} `json:"DepositStake"`

				WithdrawStake *struct {
					Amount int64                    `json:"amount"`
					Staker struct{ Address string } `json:"staker"`
					Pool   struct {
						Address string `json:"address"`
						Name    string `json:"name"`
					} `json:"pool"`
				} `json:"WithdrawStake"`

				WithdrawStakeRequest *struct {
					Amount *int64                   `json:"amount"`
					Staker struct{ Address string } `json:"staker"`
					Pool   struct {
						Address string `json:"address"`
						Name    string `json:"name"`
					} `json:"pool"`
				} `json:"WithdrawStakeRequest"`

				JettonMint *struct {
					Recipient *struct{ Address string } `json:"recipient"`
					Amount    string                    `json:"amount"`
					Jetton    struct {
						Symbol   string `json:"symbol"`
						Decimals int    `json:"decimals"`
						Image    string `json:"image"`
					} `json:"jetton"`
				} `json:"JettonMint"`

				JettonBurn *struct {
					Sender *struct{ Address string } `json:"sender"`
					Amount string                    `json:"amount"`
					Jetton struct {
						Symbol   string `json:"symbol"`
						Decimals int    `json:"decimals"`
						Image    string `json:"image"`
					} `json:"jetton"`
				} `json:"JettonBurn"`

				SmartContractExec *struct {
					Executor struct{ Address string } `json:"executor"`
					Contract struct{ Address string } `json:"contract"`
					TonAttached int64                  `json:"ton_attached"`
					Operation string                   `json:"operation"`
				} `json:"SmartContractExec"`

				SimplePreview struct {
					Name        string `json:"name"`
					Description string `json:"description"`
				} `json:"simple_preview"`
			} `json:"actions"`
		} `json:"events"`
	}

	if err := json.Unmarshal(data, &response); err != nil {
		return nil, err
	}

	rawAddr := address
	if !strings.HasPrefix(address, "0:") && !strings.HasPrefix(address, "-1:") {
		if r, err := TONAddressToRaw(address); err == nil {
			rawAddr = r
		}
	}
	lowAddr := strings.ToLower(rawAddr)

	result := make([]ActivityItem, 0, len(response.Events))
	for _, e := range response.Events {
		for idx, a := range e.Actions {
			item := ActivityItem{
				ID:        fmt.Sprintf("%s_%d", e.EventID, idx),
				Hash:      e.EventID,
				Timestamp: e.Timestamp,
				Status:    a.Status,
			}

			switch a.Type {
			case "TonTransfer":
				if a.TonTransfer == nil {
					continue
				}
				if a.Status == "failed" {
					continue
				}
				item.Kind = "ton"
				item.Symbol = "TON"
				item.Amount = float64(a.TonTransfer.Amount) / 1e9
				item.From = a.TonTransfer.Sender.Address
				item.To = a.TonTransfer.Recipient.Address
				item.Comment = a.TonTransfer.Comment
				item.IsIncoming = strings.ToLower(item.To) == lowAddr
				if item.Amount < 0.0001 {
					continue
				}

			case "JettonTransfer":
				if a.JettonTransfer == nil {
					continue
				}
				item.Kind = "jetton"
				item.Symbol = a.JettonTransfer.Jetton.Symbol
				item.IconURL = a.JettonTransfer.Jetton.Image
				item.Comment = a.JettonTransfer.Comment
				if a.JettonTransfer.Sender != nil {
					item.From = a.JettonTransfer.Sender.Address
				}
				if a.JettonTransfer.Recipient != nil {
					item.To = a.JettonTransfer.Recipient.Address
				}
				rawAmount, _ := new(jettonBig).SetString(a.JettonTransfer.Amount)
				decimals := a.JettonTransfer.Jetton.Decimals
				if decimals == 0 {
					decimals = 9
				}
				item.Amount = rawAmount.Float() / math.Pow(10, float64(decimals))
				item.IsIncoming = strings.ToLower(item.To) == lowAddr

			case "JettonSwap":
				if a.JettonSwap == nil {
					continue
				}
				item.Kind = "swap"
				if a.JettonSwap.JettonMasterOut != nil {
					item.Symbol = a.JettonSwap.JettonMasterOut.Symbol
					item.IconURL = a.JettonSwap.JettonMasterOut.Image
					if a.JettonSwap.AmountOut != "" {
						rawAmount, _ := new(jettonBig).SetString(a.JettonSwap.AmountOut)
						decimals := a.JettonSwap.JettonMasterOut.Decimals
						if decimals == 0 {
							decimals = 9
						}
						item.Amount = rawAmount.Float() / math.Pow(10, float64(decimals))
					}
				} else if a.JettonSwap.TonOut > 0 {
					item.Symbol = "TON"
					item.Amount = float64(a.JettonSwap.TonOut) / 1e9
				}
				item.IsIncoming = true

			case "NftItemTransfer":
				if a.NftItemTransfer == nil {
					continue
				}
				item.Kind = "nft"
				item.Symbol = "NFT"
				item.Amount = 1
				if a.NftItemTransfer.Sender != nil {
					item.From = a.NftItemTransfer.Sender.Address
				}
				if a.NftItemTransfer.Recipient != nil {
					item.To = a.NftItemTransfer.Recipient.Address
				}
				item.IsIncoming = strings.ToLower(item.To) == lowAddr
				item.Comment = a.NftItemTransfer.Comment

			case "ContractDeploy":
				if a.ContractDeploy == nil {
					continue
				}
				item.Kind = "deploy"
				item.Symbol = "TON"
				item.Amount = 0
				item.To = a.ContractDeploy.Address
				item.From = item.To
				item.Comment = "Contract deployed"

			case "Subscribe", "UnSubscribe":
				sub := a.Subscribe
				if a.Type == "UnSubscribe" && a.UnSubscribe != nil {
					sub = a.UnSubscribe
				}
				if sub == nil {
					continue
				}
				item.Kind = "subscription"
				item.Symbol = "TON"
				item.Amount = float64(sub.Amount) / 1e9
				item.From = sub.Subscriber.Address
				item.To = sub.Beneficiary.Address
				item.IsIncoming = strings.ToLower(item.To) == lowAddr
				if a.Type == "UnSubscribe" {
					item.Comment = "Unsubscribed"
				} else {
					item.Comment = "Subscribed"
				}

			case "DomainRenew":
				if a.DomainRenew == nil {
					continue
				}
				item.Kind = "domain_renew"
				item.Symbol = ""
				item.Amount = 0
				item.Comment = "Renewed " + a.DomainRenew.Domain
				item.To = a.DomainRenew.ContractAddress

			case "AuctionBid":
				if a.AuctionBid == nil {
					continue
				}
				item.Kind = "auction"
				if a.AuctionBid.Amount != nil {
					item.Symbol = a.AuctionBid.Amount.TokenName
					value, _ := strconv.ParseFloat(a.AuctionBid.Amount.Value, 64)
					item.Amount = value / 1e9
				}
				item.From = a.AuctionBid.Bidder.Address
				if a.AuctionBid.NFT != nil {
					item.To = a.AuctionBid.NFT.Address
					item.IconURL = a.AuctionBid.NFT.Metadata.Image
					item.Comment = a.AuctionBid.NFT.Metadata.Name
				}

			case "DepositStake":
				if a.DepositStake == nil {
					continue
				}
				item.Kind = "stake_deposit"
				item.Symbol = "TON"
				item.Amount = float64(a.DepositStake.Amount) / 1e9
				item.From = a.DepositStake.Staker.Address
				item.To = a.DepositStake.Pool.Address
				item.Comment = "Staked in " + a.DepositStake.Pool.Name

			case "WithdrawStake":
				if a.WithdrawStake == nil {
					continue
				}
				item.Kind = "stake_withdraw"
				item.Symbol = "TON"
				item.Amount = float64(a.WithdrawStake.Amount) / 1e9
				item.IsIncoming = true
				item.To = a.WithdrawStake.Staker.Address
				item.From = a.WithdrawStake.Pool.Address
				item.Comment = "Unstaked from " + a.WithdrawStake.Pool.Name

			case "WithdrawStakeRequest":
				if a.WithdrawStakeRequest == nil {
					continue
				}
				item.Kind = "stake_unstake_request"
				item.Symbol = "TON"
				if a.WithdrawStakeRequest.Amount != nil {
					item.Amount = float64(*a.WithdrawStakeRequest.Amount) / 1e9
				}
				item.From = a.WithdrawStakeRequest.Staker.Address
				item.To = a.WithdrawStakeRequest.Pool.Address
				item.Comment = "Unstake requested from " + a.WithdrawStakeRequest.Pool.Name

			case "JettonMint":
				if a.JettonMint == nil {
					continue
				}
				item.Kind = "jetton"
				item.Symbol = a.JettonMint.Jetton.Symbol
				item.IconURL = a.JettonMint.Jetton.Image
				rawAmount, _ := new(jettonBig).SetString(a.JettonMint.Amount)
				decimals := a.JettonMint.Jetton.Decimals
				if decimals == 0 {
					decimals = 9
				}
				item.Amount = rawAmount.Float() / math.Pow(10, float64(decimals))
				if a.JettonMint.Recipient != nil {
					item.To = a.JettonMint.Recipient.Address
				}
				item.IsIncoming = true
				item.Comment = "Mint"

			case "JettonBurn":
				if a.JettonBurn == nil {
					continue
				}
				item.Kind = "jetton"
				item.Symbol = a.JettonBurn.Jetton.Symbol
				item.IconURL = a.JettonBurn.Jetton.Image
				rawAmount, _ := new(jettonBig).SetString(a.JettonBurn.Amount)
				decimals := a.JettonBurn.Jetton.Decimals
				if decimals == 0 {
					decimals = 9
				}
				item.Amount = rawAmount.Float() / math.Pow(10, float64(decimals))
				if a.JettonBurn.Sender != nil {
					item.From = a.JettonBurn.Sender.Address
				}
				item.Comment = "Burn"

			case "SmartContractExec":
				if a.SmartContractExec == nil {
					continue
				}
				item.Kind = "contract"
				item.Symbol = "TON"
				item.Amount = float64(a.SmartContractExec.TonAttached) / 1e9
				item.From = a.SmartContractExec.Executor.Address
				item.To = a.SmartContractExec.Contract.Address
				item.IsIncoming = strings.ToLower(item.To) == lowAddr
				if a.SmartContractExec.Operation != "" {
					item.Comment = a.SmartContractExec.Operation
				} else {
					item.Comment = "Smart contract call"
				}
				if item.Amount < 0.0001 {
					continue
				}

			default:
				item.Kind = "unknown"
				item.Symbol = ""
				item.Amount = 0
				if a.SimplePreview.Name != "" {
					item.Comment = a.SimplePreview.Name
				} else {
					item.Comment = a.Type
				}
			}

			result = append(result, item)
		}
	}

	return result, nil
}

type jettonBig struct {
	value float64
}

func (b *jettonBig) SetString(s string) (*jettonBig, bool) {
	v, err := strconv.ParseFloat(s, 64)
	if err != nil {
		return b, false
	}
	b.value = v
	return b, true
}

func (b *jettonBig) Float() float64 {
	return b.value
}
