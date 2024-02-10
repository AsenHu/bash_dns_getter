#!/bin/bash

# 设置缓存目录
CACHE_DIR="./tmp"
mkdir -p $CACHE_DIR

curl() {
    # Copy from https://github.com/XTLS/Xray-install
    if ! $(type -P curl) -L -q --retry 5 --retry-delay 10 --retry-max-time 60 "$@";then
        echo "ERROR:Curl Failed, check your network"
        exit 1
    fi
}

# 检查缓存是否存在，并且是否过期
get_cache() {
    local domain=$1
    local type=$2
    local cache_path="$CACHE_DIR/${domain}_${type}"

    # 如果缓存文件不存在，或过期时间小于当前时间，返回 1；否则，返回 0
    if [ ! -f "$cache_path" ]; then
        return 1
    fi

    local cache_file
    readarray -t cache_file < "$cache_path"
    local expire_time="${cache_file[-1]}"
    if [ "$(date +%s)" -gt "$expire_time" ]; then
        rm -rf "$cache_path"
        return 1
    else
        ret=("${cache_file[@]:0:${#cache_file[@]}-1}")
        return 0
    fi
}

get_dns_result() {
    local domain type cache_path json TTLs TTL ttl i
    domain=$1
    type=$2
    cache_path="$CACHE_DIR/${domain}_${type}"
    

    json=$(curl -H "accept: application/dns-json" "https://cloudflare-dns.com/dns-query?name=$domain&type=$type")
    readarray -t ret < <(echo "$json" | jq -r '.Answer | map(.data) | .[]')
    readarray -t TTLs < <(echo "$json" | jq -r '.Answer | map(.TTL) | .[]')

    # 计算数组中的最小值
    TTL=${TTLs[0]}
    for ttl in "${TTLs[@]}"
    do
        if (( ttl < TTL ))
        then
            TTL=$ttl
        fi
    done

    {
        for i in "${ret[@]}"
        do
            echo "$i"
        done
        echo $(($(date +%s) + ttl))
    } > "$cache_path"
}

# 主方法
resolve_dns() {
    local domain=$1
    local type=$2

    if ! get_cache "$domain" "$type"
    then
        get_dns_result "$domain" "$type"
    fi
}

# 调用主方法
resolve_dns "$1" "$2"

# 输出结果
echo "${ret[*]}"
