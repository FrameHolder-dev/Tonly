package middleware

import (
	"net/http"
	"sync"
	"time"
)

type visitor struct {
	tokens   float64
	lastSeen time.Time
}

var (
	visitors = make(map[string]*visitor)
	mu       sync.Mutex
	rate     = 10.0
	burst    = 20.0
)

func init() {
	go func() {
		for {
			time.Sleep(time.Minute)
			mu.Lock()
			for ip, v := range visitors {
				if time.Since(v.lastSeen) > 3*time.Minute {
					delete(visitors, ip)
				}
			}
			mu.Unlock()
		}
	}()
}

func getVisitor(ip string) *visitor {
	mu.Lock()
	defer mu.Unlock()

	v, exists := visitors[ip]
	if !exists {
		v = &visitor{tokens: burst, lastSeen: time.Now()}
		visitors[ip] = v
		return v
	}

	elapsed := time.Since(v.lastSeen).Seconds()
	v.tokens += elapsed * rate
	if v.tokens > burst {
		v.tokens = burst
	}
	v.lastSeen = time.Now()
	return v
}

func RateLimit(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		v := getVisitor(r.RemoteAddr)

		mu.Lock()
		if v.tokens < 1 {
			mu.Unlock()
			http.Error(w, http.StatusText(http.StatusTooManyRequests), http.StatusTooManyRequests)
			return
		}
		v.tokens--
		mu.Unlock()

		next.ServeHTTP(w, r)
	})
}
