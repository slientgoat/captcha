-module(captcha).
-compile(export_all).

-record(captcha,{key,sha,cryptkey}).


init()->
  case ets:info(captcha) of
    undefined ->
      captcha = ets:new(captcha, [set, public, named_table,{keypos, #captcha.key}]);
    _Info ->
      ok
  end.


new(Key) ->
  FileName = lists:flatmap(fun(Item) -> integer_to_list(Item) end, tuple_to_list(erlang:timestamp())),
  Code = generate_rand(4),
  File = io_lib:format("~s.png", [FileName]),
  Cmd = io_lib:format("convert -background 'none' -fill '#222222' -size 100 -gravity Center -wave 5x100 -swirl 50 -font DejaVu-Serif-Book -pointsize 28 label:~s -draw 'Bezier 10,40 50,35 100,35 150,35 200,50 250,35 300,35' ~s", [Code, File]),
  os:cmd(Cmd),
  CryptKey = crypto:strong_rand_bytes(16),
  {ok, BinPng} = file:read_file(File),
%%  file:delete(File),
  NewCode = string:to_lower(Code),
  Sha = crypto:hmac('sha',CryptKey, integer_to_list(lists:sum(NewCode)) ++ NewCode),
  Captcha = #captcha{key = Key,sha = Sha,cryptkey = CryptKey},
  true = ets:insert(captcha, Captcha),
  BinPng.

check(Key, Code) ->
  NewCode = string:to_lower(Code),
  Captcha = hd(ets:lookup(captcha,Key)),
  Sha =   Captcha#captcha.sha,
  case crypto:hmac('sha',Captcha#captcha.cryptkey, integer_to_list(lists:sum(NewCode)) ++ NewCode) of
    Sha ->
      true;
    _ ->
      false
  end.

generate_rand(Length) ->
  rand:seed(exs64),
  lists:foldl(fun(_I, Acc) -> [do_rand(0) | Acc] end, [], lists:seq(1, Length)).

do_rand(R) when R > 46, R < 58; R > 64, R < 91; R > 96 ->
  R;

do_rand(_R) ->
  %do_rand(48 + random:uniform(74)). %% exluding zero
  do_rand(47 + rand:uniform(75)).