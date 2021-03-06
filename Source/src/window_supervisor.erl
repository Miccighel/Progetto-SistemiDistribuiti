%% ---- MODULO WINDOW_SUPERVISOR --- %%

%% Questo modulo rappresenta il supervisore del modulo dedicato alle finestre e permette di eseguire l'impostazione
%% iniziale delle varie componenti del modulo stesso.

-module(window_supervisor).
-behaviour(supervisor).
-compile(export_all).

%% ---- FUNZIONI STANDARD DI SUPERVISOR ---- %%

%% Lancia il supervisore.

start_link(Name, ClientName) ->
  {ok, Pid} = supervisor:start_link({local, Name}, ?MODULE, ClientName),
  {ok, LogSender} = file:open("log/Log_Sender.txt", [append]),
  io:format(LogSender, "~p~p~n", ["SUPERVISORE FINESTRE: Il supervisore è stato avviato con identificatore: ", Pid]),
  io:format("SUPERVISORE FINESTRE: Il supervisore è stato avviato con identificatore: ~p~n", [Pid]),
  file:close(LogSender),
  %% Necessario restituire tale tupla per l'application controller che ha il compito di avviare l'applicazione, altrimenti
  %% restituisce un errore bad_return_value.
  {ok, Pid}.

%% Durante la fase di inizializzazione del supervisore vengono impostati i nomi locali dei processi corrispondenti alle varie
%% componenti del sistema; vengono quindi indicati i figli sotto il controllo del supervisore da lanciare andando a definire
%% le loro specifiche ed infine viene impostata la strategia globale di supervisione.

init(ClientName) ->
  process_flag(trap_exit, true),
  EventHandlerName = window_event_handler,
  Sensor1Name = window_sensor_1,
  Sensor2Name = window_sensor_2,
  MonitorName = window_network_monitor,
  %% Una singola ChildSpecification è nella forma: {ChildId, StartFunc, Restart, Shutdown, Type, Modules}.
  ChildSpecification =
    [
      {EventHandlerName, {window_event, start_link, [EventHandlerName, ClientName]}, permanent, 5000, worker, [dynamic]},
      {Sensor1Name, {window_sensor, start_link, [EventHandlerName, Sensor1Name]}, permanent, 5000, worker, [window_sensor]},
      {Sensor2Name, {window_sensor, start_link, [EventHandlerName, Sensor2Name]}, permanent, 5000, worker, [window_sensor]},
      {MonitorName, {window_network_monitor, start_link, [EventHandlerName, MonitorName]}, permanent, 5000, worker, [window_network_monitor]}
    ],
  %% Utilizzare una strategia rest_for_one significa che se una componente del sistema termina per qualsiasi motivo, vengono riavviate
  %% LA COMPONENTE STESSA E TUTTE QUELLE AVVIATE DOPO DI ESSA. Se, ad esempio, il processo sensor_2 muore, vengono fatti ripartire:
  %% sensor_2, calculator e network_monitor, nell'ordine dato.
  Strategy = {{rest_for_one, 10, 6000}, ChildSpecification},
  {ok, Strategy}.

%% Operazioni di deinizializzazione da compiere in caso di terminazione. Per il momento, nessuna.

terminate(Reason, _State) ->
  {ok, LogSender} = file:open("log/Log_Sender.txt", [append]),
  io:format(LogSender, "~p~p~p~p~n", ["SUPERVISORE FINESTRE: Il supervisore generale con identificatore ", self(), " è stato terminato per il motivo: ",
    Reason]),
  io:format("SUPERVISORE FINESTRE: Il supervisore generale con identificatore ~p e stato terminato per il motivo: ~p~n", [self(), Reason]),
  file:close(LogSender),
  ok.