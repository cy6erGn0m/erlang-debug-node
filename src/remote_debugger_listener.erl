-module(remote_debugger_listener).

% receives commands from remote debugger

-export([run/1, interpret_module/1]).

-include("process_names.hrl").
-include("remote_debugger_messages.hrl").

run(Debugger) ->
  register(?RDEBUG_LISTENER, self()),
  Debugger ! #register_listener{pid = self()},
  loop().

loop() ->
  receive
    {set_breakpoint, Module, Line} when is_atom(Module),
                                        is_integer(Line) ->
      set_breakpoint(Module, Line);
    {remove_breakpoint, Module, Line} when is_atom(Module),
                                           is_integer(Line) ->
      remove_breakpoint(Module, Line);
    {interpret_modules, Modules} when is_list(Modules) ->
      interpret_modules(Modules);
    {run_debugger, Module, Function, Args} when is_atom(Module),
                                                is_atom(Function),
                                                is_list(Args) ->
      run_debugger(Module, Function, Args);
    UnknownMessage ->
      io:format("unknown message: ~p", [UnknownMessage])
  end,
  loop().

set_breakpoint(Module, Line) ->
  Response = #set_breakpoint_response{
    module = Module,
    line = Line,
    status = int:break(Module, Line)
  },
  ?RDEBUG_NOTIFIER ! Response.

remove_breakpoint(Module, Line) ->
  int:delete_break(Module, Line).

interpret_modules(Modules) ->
  Statuses = lists:map(fun ?MODULE:interpret_module/1, Modules),
  ?RDEBUG_NOTIFIER ! #interpret_modules_response{statuses = Statuses}.

interpret_module(Module) ->
  case int:ni(Module) of
    {module, _} -> {Module, ok};
    error -> {Module, int:interpretable(Module)}
  end.

%%TODO make sure it's linked appropriately
run_debugger(Module, Function, _Args) ->
  %%FIXME provide args (also make sure to handle the case of nullary fun)
  spawn_link(Module, Function, [1]).