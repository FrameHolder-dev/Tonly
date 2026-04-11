package handler

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strconv"
	"sync/atomic"
	"time"

	"github.com/FrameHolder-dev/Tonly/backend/internal/service"
	"golang.org/x/net/websocket"
)

type Omniston struct {
	wsURL            string
	referrerAddress  string
	referrerFeeBps   int
	requestCounter   int64
}

func NewOmniston() *Omniston {
	wsURL := os.Getenv("OMNISTON_WS_URL")
	if wsURL == "" {
		wsURL = "wss://omni-ws.ston.fi"
	}
	refAddr := os.Getenv("PROTOCOL_REVENUE_ADDRESS")
	if refAddr == "" {
		refAddr = "UQAZmfST4rGbvkQvexcxWfnnRfLzNdZg52yWdL51lDEjmCLR"
	}
	if raw, err := service.TONAddressToRaw(refAddr); err == nil {
		refAddr = raw
	}
	feeBps := 10
	if v := os.Getenv("PROTOCOL_FEE_BPS"); v != "" {
		if parsed, err := strconv.Atoi(v); err == nil {
			feeBps = parsed
		}
	}
	return &Omniston{
		wsURL:           wsURL,
		referrerAddress: refAddr,
		referrerFeeBps:  feeBps,
	}
}

func (h *Omniston) nextID() string {
	n := atomic.AddInt64(&h.requestCounter, 1)
	return strconv.FormatInt(n, 10)
}

type omnistonReq struct {
	JSONRPC string `json:"jsonrpc"`
	ID      string `json:"id"`
	Method  string `json:"method"`
	Params  any    `json:"params"`
}

type QuoteRequest struct {
	BidAsset string `json:"bid_asset"`
	AskAsset string `json:"ask_asset"`
	BidUnits string `json:"bid_units,omitempty"`
	AskUnits string `json:"ask_units,omitempty"`
	Slippage int    `json:"slippage_bps,omitempty"`
}

func (h *Omniston) Quote(w http.ResponseWriter, r *http.Request) {
	var req QuoteRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.BidAsset == "" || req.AskAsset == "" || (req.BidUnits == "" && req.AskUnits == "") {
		writeError(w, http.StatusBadRequest, "bid_asset, ask_asset and amount are required")
		return
	}

	if raw, err := service.TONAddressToRaw(req.BidAsset); err == nil {
		req.BidAsset = raw
	}
	if raw, err := service.TONAddressToRaw(req.AskAsset); err == nil {
		req.AskAsset = raw
	}

	ctx, cancel := context.WithTimeout(r.Context(), 25*time.Second)
	defer cancel()

	result, err := h.fetchQuote(ctx, req)
	if err != nil {
		writeError(w, http.StatusBadGateway, fmt.Sprintf("omniston error: %v", err))
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(result)
}

func (h *Omniston) fetchQuote(ctx context.Context, req QuoteRequest) ([]byte, error) {
	origin := "https://tonly.one"
	conn, err := websocket.Dial(h.wsURL, "", origin)
	if err != nil {
		return nil, fmt.Errorf("dial: %w", err)
	}
	defer conn.Close()

	slippage := req.Slippage
	if slippage == 0 {
		slippage = 100
	}

	amountField := map[string]string{}
	if req.BidUnits != "" {
		amountField["bid_units"] = req.BidUnits
	} else {
		amountField["ask_units"] = req.AskUnits
	}

	params := map[string]any{
		"bid_asset_address": map[string]any{
			"blockchain": 607,
			"address":    req.BidAsset,
		},
		"ask_asset_address": map[string]any{
			"blockchain": 607,
			"address":    req.AskAsset,
		},
		"amount": amountField,
		"referrer_address": map[string]any{
			"blockchain": 607,
			"address":    h.referrerAddress,
		},
		"referrer_fee_bps":       h.referrerFeeBps,
		"flexible_referrer_fee":  true,
		"settlement_methods":     []int{0},
		"settlement_params": map[string]any{
			"max_price_slippage_bps": slippage,
			"max_outgoing_messages":  4,
			"gasless_settlement":     0,
		},
	}

	reqMsg := omnistonReq{
		JSONRPC: "2.0",
		ID:      h.nextID(),
		Method:  "v1beta7.quote",
		Params:  params,
	}

	if err := websocket.JSON.Send(conn, reqMsg); err != nil {
		return nil, fmt.Errorf("send: %w", err)
	}

	conn.SetDeadline(time.Now().Add(18 * time.Second))

	var ackResp struct {
		JSONRPC string          `json:"jsonrpc"`
		ID      string          `json:"id"`
		Result  json.RawMessage `json:"result,omitempty"`
		Error   *struct {
			Code    int    `json:"code"`
			Message string `json:"message"`
		} `json:"error,omitempty"`
	}
	if err := websocket.JSON.Receive(conn, &ackResp); err != nil {
		return nil, fmt.Errorf("receive ack: %w", err)
	}
	if ackResp.Error != nil {
		return nil, fmt.Errorf("ack error: %s", ackResp.Error.Message)
	}

	var subscriptionID string
	if err := json.Unmarshal(ackResp.Result, &subscriptionID); err != nil {
		var wrapped struct {
			SubscriptionID string `json:"subscription_id"`
		}
		if err2 := json.Unmarshal(ackResp.Result, &wrapped); err2 == nil {
			subscriptionID = wrapped.SubscriptionID
		}
	}

	for {
		select {
		case <-ctx.Done():
			return nil, fmt.Errorf("timeout waiting for quote")
		default:
		}

		var msg struct {
			Method string `json:"method"`
			Params struct {
				Subscription int64 `json:"subscription"`
				Result       struct {
					Event map[string]json.RawMessage `json:"event"`
				} `json:"result"`
			} `json:"params"`
		}
		if err := websocket.JSON.Receive(conn, &msg); err != nil {
			return nil, fmt.Errorf("receive: %w", err)
		}

		if msg.Method != "event" {
			continue
		}

		if quoteUpdated, ok := msg.Params.Result.Event["quote_updated"]; ok && len(quoteUpdated) > 0 {
			return quoteUpdated, nil
		}
		if noQuote, ok := msg.Params.Result.Event["no_quote"]; ok && len(noQuote) > 0 {
			return nil, fmt.Errorf("no quote available")
		}
	}
}
