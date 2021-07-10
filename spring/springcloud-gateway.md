### 解决跨域问题

```java
@Bean
    public WebFilter corsFilter() {
        return (ServerWebExchange ctx, WebFilterChain chain) -> {
            ServerHttpRequest request = ctx.getRequest();
            if (CorsUtils.isCorsRequest(request)) {
                ServerHttpResponse response = ctx.getResponse();
                HttpHeaders headers = response.getHeaders();
                headers.set("Access-Control-Allow-Origin", ALL);
                headers.add("Access-Control-Allow-Methods", ALL);
                headers.add("Access-Control-Max-Age", MAX_AGE);
                headers.add("Access-Control-Allow-Headers", ALL);
                headers.add("Access-Control-Expose-Headers", ALL);
                headers.add("Access-Control-Allow-Credentials", "true");
                if (request.getMethod() == HttpMethod.OPTIONS) {
                    response.setStatusCode(HttpStatus.OK);
                    return Mono.empty();
                }
            }
            return chain.filter(ctx);
        };
    }
    
    @Component("corsResponseHeaderFilter")
    public class CorsResponseHeaderFilter implements GlobalFilter, Ordered {

        @Override
        public int getOrder() {
            // 指定此过滤器位于NettyWriteResponseFilter之后
            // 即待处理完响应体后接着处理响应头
            return NettyWriteResponseFilter.WRITE_RESPONSE_FILTER_ORDER + 1;
        }

        @Override
        public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
            return chain.filter(exchange).then(Mono.defer(() -> {
                exchange.getResponse().getHeaders().entrySet().stream()
                        .filter(kv -> (kv.getValue() != null && kv.getValue().size() > 1))
                        .filter(kv -> (kv.getKey().equals(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN)
                                || kv.getKey().equals(HttpHeaders.ACCESS_CONTROL_ALLOW_CREDENTIALS)))
                        .forEach(kv -> {
                            kv.setValue(new ArrayList<String>() {{
                                add(kv.getValue().get(0));
                            }});
                        });

                return chain.filter(exchange);
            }));
        }
```