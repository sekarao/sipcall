# sipcall

SIP сервер, работающий на Docker

## Запуск через Docker

Чтобы запустить сервер, необходимо перейти в папку с проектом и построить образ командой
`sudo docker build -t sipcall .`

Затем нужно запустить контейнер на основе этого образа
`sudo docker run --rm -it --network host sipcall`

Сервер запущен, теперь необходимо запустить twinkle и настроить там пользователей. В базе пользователей сейчас есть запись только об одном пользователе, при желании можно добавить туда других:
```json
{
    "users": [
        {"userID" : "0",
         "userName" : "ivanov",
         "userPhone" : "3003",
         "userAuth": {
            "authType" : "yes",
            "userLogin" : "3003",
            "userPass": "test"
         }
        }
    ]
}
```
В twinkle необходимо настроить сеть, поставить SIP порт 5062, чтобы он не конфликтовал с сервером, который слушает SIP порт 5060. Также в настройках пользователя нужно указать его логин (3003), пароль (test) и домен (localhost), а также во вкладке SIP сервер поставить регистратор localhost.

Если запустить twinkle с данными настройками, то пользователь автоматически пройдет регистрацию и сможет звонить другим пользователям.
## Регистрация
Логи сервера:
```erlang
sip_server: sip_authorize()
sip_server: trying to auth user []
sip_server: sip_authorize()
sip_server: trying to auth user []
sip_server: sip_authorize()
sip_server: trying to auth user []
sip_server: sip_get_user_pass(<<"3003">>)
sip_server: sip_authorize()
sip_server: trying to auth user []
sip_server: sip_route(User = <<>>)
sip_server: sip_register(From <<"3003">>)
REGISTER OK: {<<"3003">>,<<"localhost">>}
sip_server: sip_authorize()
sip_server: trying to auth user []
sip_server: sip_authorize()
sip_server: trying to auth user []
sip_server: sip_route(User = <<"3003">>)
```

Логи twinkle:
```
Сб 18:55:11
3003, регистрация завершена (устаревание = 3600 секунд)
```
## Звонок другому пользователю
Логи сервера:
```erlang
sip_server: sip_authorize()
sip_server: trying to auth user []
sip_server: sip_route(User = <<"3004">>)
sip_server: sip_invite(From <<"3003">>, User <<"3004">>)
```

Логи twinkle:
```
Сб 18:56:53
Линия 1: Ошибка звонка.
487 Request Terminated
```
Звонок на сервер отклоняется, но запоминается Uri звонившего в ETS таблицу. 
## Звонок другому пользователю
Также реализован простой http сервер cowboy, он позволяет обрабатывать GET запросы на `/api/call/:userid`, где userid это логин пользователя. Если этот пользователь уже звонил на сервер, то при GET запросе сервер ему перезвонит.

Запрос можно сделать командой
`curl -v http://localhost:8080/api/call/3003`

Логи сервера:
```erlang
\x{412}\x{44B}\x{437}\x{43E}\x{432} \x{43F}\x{43E}\x{43B}\x{44C}\x{437}\x{43E}\x{432}\x{430}\x{442}\x{435}\x{43B}\x{44F} <<"3003">>
sip_client: calling back to client {uri,sip,<<"3003">>,<<>>,<<"127.0.0.1">>,
                                       5062,<<>>,[],[],[],[],<<>>}
```

Логи twinkle:
```
Сб 19:04:11
Линия 1: входящий звонок для sip:3003@127.0.0.1

Сб 19:04:13
Линия 1: звонок сброшен.
```

Логи curl. Получаем ответ `{"status":"calling","userid":"3003"}`:
```
sekarao@sekarao-pc:~$ curl -v http://localhost:8080/api/call/3003
* Host localhost:8080 was resolved.
* IPv6: ::1
* IPv4: 127.0.0.1
*   Trying [::1]:8080...
* connect to ::1 port 8080 from ::1 port 34502 failed: В соединении отказано
*   Trying 127.0.0.1:8080...
* Established connection to localhost (127.0.0.1 port 8080) from 127.0.0.1 port 52424 
* using HTTP/1.x
> GET /api/call/3003 HTTP/1.1
> Host: localhost:8080
> User-Agent: curl/8.18.0
> Accept: */*
> 
* Request completely sent off
< HTTP/1.1 200 OK
< content-length: 36
< content-type: application/json
< date: Sat, 06 Jun 2026 12:04:12 GMT
< server: Cowboy
< 
* Connection #0 to host localhost:8080 left intact
{"status":"calling","userid":"3003"}
```

Если же сделать запрос для пользователя который еще не звонил на сервер, то получим ответ `{"error":"User not found"}`:
```
sekarao@sekarao-pc:~$ curl -v http://localhost:8080/api/call/3004
* Host localhost:8080 was resolved.
* IPv6: ::1
* IPv4: 127.0.0.1
*   Trying [::1]:8080...
* connect to ::1 port 8080 from ::1 port 52736 failed: В соединении отказано
*   Trying 127.0.0.1:8080...
* Established connection to localhost (127.0.0.1 port 8080) from 127.0.0.1 port 51258 
* using HTTP/1.x
> GET /api/call/3004 HTTP/1.1
> Host: localhost:8080
> User-Agent: curl/8.18.0
> Accept: */*
> 
* Request completely sent off
< HTTP/1.1 404 Not Found
< content-length: 26
< content-type: application/json
< date: Sat, 06 Jun 2026 12:05:22 GMT
< server: Cowboy
< 
* Connection #0 to host localhost:8080 left intact
{"error":"User not found"}
```
