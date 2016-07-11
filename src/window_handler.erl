%% ---- MODULO WINDOW_HANDLER --- %%

%% Questo modulo è l'implementazione concreta di uno degli handler associabili ad un event handler OTP, che ha, come scopo,
%% la gestione di tutti gli eventi legati ai sensori per la verifica dello stato delle finestre.

-module(window_handler).
-behaviour(gen_event).
-compile(export_all).

% --- FUNZIONI STANDARD DI GEN_EVENT --- %

%% Inizializza lo stato dell'handler, preparando le strutture dati per la configurazione delle finestre, per gli identificatori
%% dei sensori, e per il nome del client in modalità sender. Viene inoltre definita la dimensione massima della struttura
%% dati contenente lo storico delle medie stesse. I riferimenti a tali strutture vengono poi salvati nello stato.
%% Ogni sensore, infatti, fa riferimento ad una finestra e le configurazioni possibili vengono rappresentate da un numero
%% intero pari a zero o uno, che vuol dire aperta o chiusa. Tali valori vengono memorizzati in un dizionario, struttura dati
%% che archivia coppie chiave/valore. In questo caso, la chiave è rappresentata dall'identificatore del sensore che ha inviato
%% il dato, ed il valore è il numero stesso. In tal modo, è possibile mantenere in memoria solamente il valore di configurazione
%% più aggiornato per ogni sensore, ovvero per ogni finestra.

init(ClientName) ->
  process_flag(trap_exit, true),
  io:format("GESTORE FINESTRE: Gestore di eventi in esecuzione con identificatore: ~p~n", [self()]),
  Status = dict:new(),
  Sensors = [],
  Data = {{status, Status}, {sensors, Sensors}, {client,ClientName}},
  {ok, Data}.

%% Operazioni di deinizializzazione da compiere in caso di terminazione. Per il momento, nessuna.

terminate(Reason, _State) ->
  io:format("GESTORE FINESTRE: Il gestore di eventi con identificatore ~p e stato terminato per il motivo: ~p~n", [self(), Reason]),
  ok.

%% Gestione della modifica a runtime del codice.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

% --- GESTIONE DEGLI EVENTI --- %

%% Gestione di un evento di registrazione di un sensore. Viene prevelata la struttura dati contenente gli identificatori
%% dei sensori ed essa viene aggiornata inserendo il nuovo identificatore giunto mediante notify. La struttura dati, infine,
%% viene aggiornata e reinserita nello stato.

handle_event({register, Value}, State) ->
  {_Dataslot_1, Dataslot_2, _Dataslot_3} = State,
  {sensors, Sensors} = Dataslot_2,
  UpdatedSensors = lists:append(Sensors, [{erlang:localtime(), Value}]),
  io:format("GESTORE FINESTRE: Nuovo sensore registrato presso l'event handler delle finestre con identificatore: ~p~n", [Value]),
  NewState = {_Dataslot_1, {sensors, UpdatedSensors}, _Dataslot_3},
  {ok, NewState};

%% Gestione di un evento di invio di un valore grezzo da parte di un sensore. Viene prelevato il dizionario contenente la
%% configurazione delle finestre ed esso viene aggiornato inserendo il nuovo valore giunto mediante notify. Il dizionario,
%% infine, viene reinserito nello stato.

handle_event({send, Value, From}, State) ->
  {Dataslot_1, _Dataslot_2, _Dataslot_3} = State,
  {status, Status} = Dataslot_1,
  UpdatedStatus = dict:store(From, Value, Status),
  io:format("GESTORE FINESTRE: Stato ricevuto pari a: ~p~n", [Value]),
  io:format("GESTORE FINESTRE: Il valore è stato inviato dal sensore con identificatore: ~p~n", [From]),
  NewState = {{status, UpdatedStatus}, _Dataslot_2, _Dataslot_3},
  {ok, NewState}.

% --- GESTIONE DELLE CHIAMATE SINCRONE --- %

%% La seguente funzione consente di fornire al client avviato in modalità sender la configurazione delle finestre al client
%% avviato in modalità sender. Quello che viene fatto consiste nell'analizzare il valore più recente inviato da ogni sensore
%% memorizzato nel dizionario. Se tutti i valori sono pari ad uno vuol dire che tutte le finestre sono chiuse e, dunque, viene
%% passato un atomo che rappresenta tale situazione. Se vi sono finestre aperte, viene passato il dizionario, in modo da poter
%% determinare quali sono effettivamente aperte.

handle_call(ask_for_status, State) ->
  {Dataslot_1, _Dataslot_2, _Dataslot_3} = State,
  {status,Status} = Dataslot_1,
  List = dict:to_list(Status),
  Sum = lists:foldl(fun({_S,V}, Sum) -> V + Sum end, 0, List),
  case Sum of
    N when N == length(List) ->
      {ok,all_windows_are_closed,State};
    _ ->
      {ok,dict:to_list(Status),State}
  end.

% --- GESTIONE DEI MESSAGGI --- %

%% Non viene effettuata alcuna particolare gestione di eventuali messaggi non trattati con le funzioni precedenti.

handle_info(Message, State) ->
  io:format("GESTORE FINESTRE: Messaggio ricevuto: ~p~n", [Message]),
  {noreply, State}.


