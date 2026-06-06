%%
%% SIP server: gen_server + nksip behaviour
%%
-module(sip_server).

-export([schedule_callback/1]).
-export([sip_get_user_pass/4, sip_authorize/3, sip_route/5, sip_register/2, sip_invite/2]).

-include_lib("nkserver/include/nkserver_module.hrl").
%% SIP callbacks: https://github.com/NetComposer/nksip/blob/master/doc/reference/callback_functions.md

schedule_callback(TargetUri) ->
    %% Обратный звонок клиенту через 10 секунд (pong)
    {ok, _} = timer:apply_after(10000, sip_client, call, [TargetUri]),
    io:format("sip_server: schedule_callback: wait timeout 10 sec...~n").

%% Called to check the user password for a realm
sip_get_user_pass(User, _Realm, _Req, _Call) ->
    io:format("sip_server: sip_get_user_pass(~p)~n", [User]),
    find_pass_userauth(User).

%% Called for every incoming request to be authorized or not
sip_authorize(AuthList, Req, _Call) ->
    io:format("sip_server: sip_authorize()~n"),
    Method = nksip_sipmsg:get_meta(method, Req),
    FromUser = nksip_sipmsg:get_meta(from_user, Req),
    FoundedUser = find_user_no_auth(FromUser),
    io:format("sip_server: trying to auth user ~p~n", [FoundedUser]),
    case lists:member(dialog, AuthList) orelse lists:member(register, AuthList) of
        true -> ok;
        false when Method =:= 'INVITE' -> ok;
        false when Method =:= 'REGISTER' andalso FoundedUser =/= [] -> ok;
        false ->
            case proplists:get_value({digest, <<"nksip">>}, AuthList) of
                true -> ok;
                false -> forbidden;
                undefined -> {proxy_authenticate, <<"nksip">>}
            end
    end.

%% This function is called by NkSIP for every new request, to check if it must be proxied, processed locally or replied immediately
sip_route(_Scheme, <<>>, <<"localhost">>, _Req, _Call) ->
    % we want to act as an endpoint or B2BUA
    io:format("sip_server: sip_route(User = <<>>)~n"),
    process;

sip_route(_Scheme, User, _Domain, Req, _Call) ->
    io:format("sip_server: sip_route(User = ~p)~n", [User]),
    case nksip_request:is_local_ruri(Req) of
        true ->
            process;
        false ->
            proxy
    end.

%% This function is called by NkSIP to process a new incoming REGISTER request
sip_register(Req, _Call) ->
    {ok, [{from_scheme, FromScheme}, {from_user, FromUser}, {from_domain, FromDomain}]} =
        nksip_request:get_metas([from_scheme, from_user, from_domain], Req),
    {ok, [{to_scheme, ToScheme}, {to_user, ToUser}, {to_domain, ToDomain}]} =
        nksip_request:get_metas([to_scheme, to_user, to_domain], Req),

    io:format("sip_server: sip_register(From ~p)~n", [FromUser]),
    case {FromScheme, FromUser, FromDomain} of
        {ToScheme, ToUser, ToDomain} ->
            io:format("REGISTER OK: ~p~n", [{ToUser, ToDomain}]),
            {reply, nksip_registrar:request(Req)};
        _ ->
            {reply, forbidden}
    end.

%% This function is called by NkSIP to process a new INVITE request as an endpoint
sip_invite(Req, _Call) ->
    {ok, [{scheme, Scheme}, {from_user, FromUser}, {user, User}, {domain, Domain}]} =
        nksip_request:get_metas([scheme, from_user, user, domain], Req),

    io:format("sip_server: sip_invite(From ~p, User ~p)~n", [FromUser, User]),
    case nksip_registrar:find(?MODULE, Scheme, FromUser, Domain) of
        [] ->
            {reply, forbidden};
        _UriList ->
            {ok, Body} = nksip_request:body(Req),
            case nksip_sdp:is_sdp(Body) of
                true ->
                    Contact = nksip_sipmsg:get_meta(contacts, Req),
                    % Планируем ответный звонок клиенту через 10 секунд
                    % io:format("sip_server: schedule callback to ~p~n", [Contact]),
                    % schedule_callback(Contact),
                    [Uri | _] = Contact,
                    ets:insert(users_table, {FromUser, Uri}),
                    % Ответ клиенту retry-after (487), чтоб перезвонить абоненту
                    {reply, {487, []}};
                false ->
                    {reply, forbidden}
            end
    end.

%% Private functions

get_users_from_json() ->
    {ok, Binary} = file:read_file("priv/users.json"),
    Output = jsx:decode(Binary),
    #{<<"users">> := Users} = Output,
    Users.

find_user_no_auth(UserFrom) ->
    Users = get_users_from_json(),
    Filter = fun(UserMap) ->
        Auth = maps:get(<<"userAuth">>, UserMap),
        UserPhone = maps:get(<<"userPhone">>, UserMap),
        AuthType = maps:get(<<"authType">>, Auth),
        AuthType == <<"no">> andalso UserPhone == UserFrom
    end,
    lists:filter(Filter, Users).

find_pass_userauth(User) ->
    Users = get_users_from_json(),
    Filter = fun(UserMap) ->
        Auth = maps:get(<<"userAuth">>, UserMap),
        Login = maps:get(<<"userLogin">>, Auth),
        AuthType = maps:get(<<"authType">>, Auth),
        AuthType == <<"yes">> andalso Login == User
    end,
    UserList = lists:filter(Filter, Users),
    case UserList of
        [] -> <<>>;
        _ ->
            [UserMap] = UserList,
            #{<<"userAuth">> := UserAuth} = UserMap,
            #{<<"userPass">> := UserPass} = UserAuth,
            UserPass
    end.
