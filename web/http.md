### http
http是无状态的应用层协议。
通过URL重写、隐藏表单域、session、cookie解决无状态。
- URL重写:URL回写是指服务器在发送给浏览器页面的所有链接中都携带JSESSIONID的参数，这样客户端点击任何一个链接都会把JSESSIONID带会服务器。如果直接在浏览器输入服务端资源的url来请求该资源，那么Session是匹配不到的。Tomcat 对Session的实现，是一开始同时使用Cookie和URL回写机制，如果发现客户端支持Cookie，就继续使用Cookie，停止使用URL回 写。如果发现Cookie被禁用，就一直使用URL回写。
- 隐藏表单域:这个原理和Cookies大同小异，只是每次请求和响应所附带的信息变成了表单变量。