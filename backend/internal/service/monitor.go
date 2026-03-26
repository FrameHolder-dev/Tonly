package service

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"sync"
	"time"
)

type TransactionMonitor struct {
	api        *TonAPI
	lastSeen   map[string]int64
	mu         sync.RWMutex
	onNewTx    func(address, from string, amount float64)
}

func NewTransactionMonitor(onNewTx func(address, from string, amount float64)) *TransactionMonitor {
	return &TransactionMonitor{
		api:      NewTonAPI(),
		lastSeen: make(map[string]int64),
		onNewTx:  onNewTx,
	}
}

func (m *TransactionMonitor) Watch(address string) {
	m.mu.Lock()
	if _, exists := m.lastSeen[address]; !exists {
		m.lastSeen[address] = time.Now().Unix()
	}
	m.mu.Unlock()
}

func (m *TransactionMonitor) Start(ctx context.Context) {
	ticker := time.NewTicker(15 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			m.checkAll(ctx)
		}
	}
}

func (m *TransactionMonitor) checkAll(ctx context.Context) {
	m.mu.RLock()
	addresses := make(map[string]int64)
	for addr, ts := range m.lastSeen {
		addresses[addr] = ts
	}
	m.mu.RUnlock()

	for addr, lastTS := range addresses {
		m.checkAddress(ctx, addr, lastTS)
	}
}

func (m *TransactionMonitor) checkAddress(ctx context.Context, address string, lastTS int64) {
	data, err := m.api.GetEvents(ctx, address, "5")
	if err != nil {
		return
	}

	var response struct {
		Events []struct {
			Timestamp int64 `json:"timestamp"`
			Actions   []struct {
				Type        string `json:"type"`
				TonTransfer *struct {
					Sender struct {
						Address string `json:"address"`
					} `json:"sender"`
					Recipient struct {
						Address string `json:"address"`
					} `json:"recipient"`
					Amount int64 `json:"amount"`
				} `json:"ton_transfer"`
			} `json:"actions"`
		} `json:"events"`
	}

	if err := json.Unmarshal(data, &response); err != nil {
		return
	}

	newLastTS := lastTS
	for _, event := range response.Events {
		if event.Timestamp <= lastTS {
			continue
		}
		if event.Timestamp > newLastTS {
			newLastTS = event.Timestamp
		}

		for _, action := range event.Actions {
			if action.Type == "TonTransfer" && action.TonTransfer != nil {
				tf := action.TonTransfer
				if tf.Recipient.Address == address {
					amount := float64(tf.Amount) / 1e9
					if amount >= 0.001 {
						sender := tf.Sender.Address
						if len(sender) > 8 {
							sender = sender[:4] + "..." + sender[len(sender)-4:]
						}
						amountStr := fmt.Sprintf("%.2f", math.Round(amount*100)/100)
						m.onNewTx(address, sender, amount)
						fmt.Printf("monitor: new tx to %s: +%s TON from %s\n", address[:8], amountStr, sender)
					}
				}
			}
		}
	}

	if newLastTS > lastTS {
		m.mu.Lock()
		m.lastSeen[address] = newLastTS
		m.mu.Unlock()
	}
}
