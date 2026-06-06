FROM erlang:21

WORKDIR /app

COPY rebar.config ./

RUN rebar3 deps

COPY . .

RUN rebar3 compile

EXPOSE 5060 5075 8080

CMD ["rebar3", "shell", "--apps", "sipcall"]
