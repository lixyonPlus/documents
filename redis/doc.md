### redis中zset实现排行榜
```
//添加玩家分数
ZADD page_rank 10 user1
ZADD page_rank 20 user2
ZADD page_rank 30 user3
//查询玩家的分数
ZSCORE page_rank user1
//按名次查看排行榜(由高到低排序)
zrevrange page_rank  0 -1 [withscores]
//按名次查看排行榜(由低到高排序)
zrange page_rank  0 -1 [withscores]
//查询前三名玩家分数(由高到低排序)
zrevrange page_rank 0 2 withscores
//查看玩家排名(由高到低排序)
zrevrank page_rank user3
//增减玩家分数
zincrby page_rank 100 user1
//移除玩家
zrem page_rank user1
//删除排行榜
del page_rank
//如果分数相同，reids按照key字典顺序排序的，可以考虑在分数中加入时间戳
带时间戳的分数 = 实际分数*10000000000 + (9999999999 – timestamp)

```


