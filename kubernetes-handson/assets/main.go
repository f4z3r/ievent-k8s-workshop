package main

import (
    "os"
    "fmt"
    "html"
    "log"
    "time"
    "io/ioutil"
    "net/http"
    "github.com/go-redis/redis/v8"
    "context"
)


func main() {
    redisPassword := os.Getenv("REDIS_PW")
    redisBaseURL := os.Getenv("REDIS_BASE_URL")

    if redisPassword == "" {
        log.Fatal("failed to read password from REDIS_PW env variable")
    }

    if redisBaseURL == "" {
        log.Fatal("failed to read Redis base URL from REDIS_BASE_URL env variable")
    }

    addrs := []string{}
    for idx := 0; idx < 6; idx++ {
        addrs = append(addrs, fmt.Sprintf("%s-%d.%s-headless:6379", redisBaseURL, idx, redisBaseURL))
    }

    rdb := redis.NewClusterClient(&redis.ClusterOptions{
        Addrs: addrs,
        Password: redisPassword,
    })

    ctx := context.TODO()

    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        key := html.EscapeString(r.URL.Path[1:])
        log.Printf("%s called for key %s", r.Method, key)

        if r.Method == "GET" {
            val, err := rdb.Get(ctx, key).Result()
            switch {
            case err == redis.Nil:
                fmt.Fprintf(w, "key '%s' does not exist\n", key)
            case err != nil:
                fmt.Fprintf(w, "Get failed: %s\n", err)
            default:
                fmt.Fprintf(w, "%s=%s\n", key, val)
            }
        }

        if r.Method == "PUT" {
            data, err := ioutil.ReadAll(r.Body)
            if err != nil {
                http.Error(w, "failed to get request data!", 500) 
            }
            value := string(data)
            err = rdb.Set(ctx, key, value, time.Duration(48*time.Hour)).Err()
            if err != nil {
                fmt.Fprintf(w, "Set failed: %s\n", err)
            } else {
                fmt.Fprintf(w, "set %s to value %s\n", key, value)
            }
        }
    })

    // For liveness probe
    http.HandleFunc("/liveness", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprint(w, "live!\n")
    })

    // For readiness probe
    http.HandleFunc("/readiness", func(w http.ResponseWriter, r *http.Request) {
        err := rdb.ForEachShard(ctx, func(ctx context.Context, shard *redis.Client) error {
            return shard.Ping(ctx).Err()
        })

        if err != nil {
           http.Error(w, "not ready yet!", 500) 
        } else {
            fmt.Fprint(w, "ready!\n")
        }
    })

    log.Fatal(http.ListenAndServe(":8080", nil))
}
