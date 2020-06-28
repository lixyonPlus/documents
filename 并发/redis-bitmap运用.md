bitmap：
  应用场景：
    统计上亿的日活跃用户
      1.为了统计今日登录的用户数，我们建立了一个bitmap,每一位标识一个用户ID。当某个用户访问我们的网页或执行了某个操作，就在bitmap中把标识此用户的位置为1。在Redis中获取此bitmap的key值是通过用户执行操作的类型和时间戳获得的。
      2.这个简单的例子中，每次用户登录时会执行一次redis.setbit(daily_active_users, user_id, 1)。将bitmap中对应位置的位置为1，时间复杂度是O(1)。统计bitmap结果显示有今天有9个用户登录。Bitmap的key是daily_active_users，它的值是1011110100100101。
      3.因为日活跃用户每天都变化，所以需要每天创建一个新的bitmap。我们简单地把日期添加到key后面，实现了这个功能。例如，要统计某一天有多少个用户至少听了一个音乐app中的一首歌曲，可以把这个bitmap的redis key设计为play:yyyy-mm-dd-hh。当用户听了一首歌曲，我们只是简单地在bitmap中把标识这个用户的位置为1，时间复杂度是O(1)。


