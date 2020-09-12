-module(els_dap_general_provider).

-behaviour(els_provider).
-export([ handle_request/2
        , is_enabled/0
        ]).

-export([ capabilities/0
        ]).

-include("erlang_ls.hrl").

%%==============================================================================
%% Types
%%==============================================================================

-type capabilities() :: #{}.
-type initialize_request() :: {initialize, initialize_params()}.
-type initialize_params() :: #{ processId             := number() | null
                              , rootPath              => binary() | null
                              , rootUri               := uri() | null
                              , initializationOptions => any()
                              , capabilities          := client_capabilities()
                              , trace                 => off
                                                       | messages
                                                       | verbose
                              , workspaceFolders      => [workspace_folder()]
                                                       | null
                              }.
-type initialize_result() :: capabilities().
-type initialized_request() :: {initialized, initialized_params()}.
-type initialized_params() :: #{}.
-type initialized_result() :: null.
-type shutdown_request() :: {shutdown, shutdown_params()}.
-type shutdown_params() :: #{}.
-type shutdown_result() :: null.
-type exit_request() :: {exit, exit_params()}.
-type exit_params() :: #{status => atom()}.
-type exit_result() :: null.
-type state() :: any().

%%==============================================================================
%% els_provider functions
%%==============================================================================

-spec is_enabled() -> boolean().
is_enabled() -> true.

-spec handle_request( initialize_request()
                    | initialized_request()
                    | shutdown_request()
                    | exit_request()
                    , state()) ->
        { initialize_result()
        | initialized_result()
        | shutdown_result()
        | exit_result()
        , state()
        }.
handle_request({initialize, _Params}, State) ->
  %% RootUri = case RootUri0 of
  %%             null ->
  %%               {ok, Cwd} = file:get_cwd(),
  %%               els_uri:uri(els_utils:to_binary(Cwd));
  %%             _ -> RootUri0
  %%           end,
  %% InitOptions = case maps:get(<<"initializationOptions">>, Params, #{}) of
  %%                 InitOptions0 when is_map(InitOptions0) ->
  %%                   InitOptions0;
  %%                 _ -> #{}
  %%               end,
  %% ok = els_config:initialize(RootUri, Capabilities, InitOptions),
  %% NewState = State#{ root_uri => RootUri, init_options => InitOptions},
  {capabilities(), State};
handle_request({initialized, _Params}, State) ->
  #{root_uri := RootUri, init_options := InitOptions} = State,
  DbDir = application:get_env(erlang_ls, db_dir, default_db_dir()),
  OtpPath = els_config:get(otp_path),
  NodeName = node_name(RootUri, els_utils:to_binary(OtpPath)),
  els_db:install(NodeName, DbDir),
  case maps:get(<<"indexingEnabled">>, InitOptions, true) of
    true  -> els_indexing:start();
    false -> lager:info("Skipping Indexing (disabled via InitOptions)")
  end,
  {null, State};
handle_request({shutdown, _Params}, State) ->
  {null, State};
handle_request({exit, #{status := Status}}, State) ->
  lager:info("Language server stopping..."),
  ExitCode = case Status of
               shutdown -> 0;
               _        -> 1
             end,
  els_utils:halt(ExitCode),
  {null, State}.

%%==============================================================================
%% API
%%==============================================================================

-spec capabilities() -> capabilities().
capabilities() ->
  #{}.

%%==============================================================================
%% Internal Functions
%%==============================================================================
-spec node_name(uri(), binary()) -> atom().
node_name(RootUri, OtpPath) ->
  <<SHA:160/integer>> = crypto:hash(sha, <<RootUri/binary, OtpPath/binary>>),
  list_to_atom(lists:flatten(io_lib:format("erlang_ls_~40.16.0b", [SHA]))).

-spec default_db_dir() -> string().
default_db_dir() ->
  filename:basedir(user_cache, "erlang_ls").
