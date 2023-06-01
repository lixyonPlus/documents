# apisix新增lua插件
1. 编写插件
2. *.lua插件放置到apisix中（例如：/example/apisix/plugins/hc-restriction.lua）
3. 修改apisix的conf.yml文件，新增插件到文件中
4. 插件查看及加载
- curl http://127.0.0.1:9180/apisix/admin/plugins?all=true -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' -X GET
- curl http://127.0.0.1:9180/apisix/admin/plugins/reload -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' -X PUT
5. apisix插件导出为schema.json文件
- curl 127.0.0.1:9092/v1/schema > schema.json
6. schema.json放置到apisix-dashboard中（位置：/usr/local/apisix-dashboard/conf/schema.json）
7. 修改apisix-dashboard的conf.yml文件，新增插件到文件中
8. 重启apisix-dashboard
