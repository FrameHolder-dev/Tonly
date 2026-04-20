package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/FrameHolder-dev/Tonly/backend/internal/config"
	"github.com/FrameHolder-dev/Tonly/backend/internal/handler"
	"github.com/FrameHolder-dev/Tonly/backend/internal/middleware"
	"github.com/FrameHolder-dev/Tonly/backend/internal/service"
)

func main() {
	cfg := config.Load()

	mux := http.NewServeMux()

	health := handler.NewHealth()
	wallet := handler.NewWallet()
	jettons := handler.NewJettons()
	nft := handler.NewNFT()
	rates := handler.NewRates()
	dns := handler.NewDNS()
	staking := handler.NewStaking()
	send := handler.NewSend()
	swap := handler.NewSwap()
	notify := handler.NewNotify()
	push := handler.NewPush()
	monitor := service.NewTransactionMonitor(func(address, from string, amount float64) {
		title := "Received TON"
		body := fmt.Sprintf("+%.2f TON from %s", amount, from)
		_ = push.SendToAddress(address, title, body)
	})
	push.SetMonitor(monitor)
	go monitor.Start(context.Background())
	tonConnect := handler.NewTonConnect()
	omniston := handler.NewOmniston()
	wsHub := handler.NewWSHub()

	mux.HandleFunc("GET /health", health.Check)

	mux.HandleFunc("GET /api/v1/time", wallet.GetTime)
	mux.HandleFunc("POST /api/v1/send/emulate", wallet.EmulateTransaction)
	mux.HandleFunc("GET /api/v1/jetton/{jetton}/payload/{address}", wallet.GetJettonPayload)
	mux.HandleFunc("GET /api/v1/wallet/generate", wallet.GenerateMnemonic)
	mux.HandleFunc("POST /api/v1/wallet/entropy", wallet.GenerateEntropy)
	mux.HandleFunc("GET /api/v1/wallet/{address}", wallet.GetBalance)
	mux.HandleFunc("GET /api/v1/wallet/{address}/overview", wallet.GetOverview)
	mux.HandleFunc("GET /api/v1/wallet/{address}/account", wallet.GetAccount)
	mux.HandleFunc("GET /api/v1/wallet/{address}/transactions", wallet.GetTransactions)
	mux.HandleFunc("GET /api/v1/wallet/{address}/activity", wallet.GetActivity)
	mux.HandleFunc("GET /api/v1/wallet/{address}/events", wallet.GetEvents)
	mux.HandleFunc("GET /api/v1/wallet/{address}/seqno", wallet.GetSeqno)

	mux.HandleFunc("GET /api/v1/wallet/{address}/jettons", jettons.GetByAddress)

	mux.HandleFunc("GET /api/v1/wallet/{address}/nfts", nft.GetByAddress)

	mux.HandleFunc("GET /api/v1/rates", rates.Get)
	mux.HandleFunc("GET /api/v1/rates/chart", rates.GetChart)

	mux.HandleFunc("GET /api/v1/dns/{domain}", dns.Resolve)

	mux.HandleFunc("GET /api/v1/wallet/{address}/staking", staking.GetPools)

	mux.HandleFunc("POST /api/v1/notify", notify.Subscribe)
	mux.HandleFunc("POST /api/v1/push/register", push.Register)
	mux.HandleFunc("POST /api/v1/send", send.SendTransaction)

	mux.HandleFunc("/api/v1/bridge", tonConnect.Bridge)
	mux.HandleFunc("GET /api/v1/tonconnect-manifest.json", tonConnect.GetManifest)
	mux.HandleFunc("GET /api/v1/send/{address}/estimate", send.EstimateFee)

	mux.HandleFunc("POST /api/v1/swap/simulate", swap.Simulate)
	mux.HandleFunc("GET /api/v1/swap/assets", swap.GetAssets)
	mux.HandleFunc("POST /api/v1/swap/quote", omniston.Quote)
	mux.HandleFunc("POST /api/v1/swap/build", omniston.Build)

	mux.Handle("/ws", wsHub.Handler())

	wrapped := middleware.Chain(
		mux,
		middleware.Logger,
		middleware.CORS,
		middleware.Recovery,
		middleware.RateLimit,
	)

	srv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      wrapped,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		log.Printf("starting server on :%s", cfg.Port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("server error: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	log.Println("shutting down server")
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("shutdown error: %v", err)
	}
}
