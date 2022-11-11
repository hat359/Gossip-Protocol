-module(gossip).
-compile(export_all).

%__________________________________________________________________________________________________________________
%This function acts as the starting function which has inputs of number of nodes, Topology and algorithm to be used
start(Num, Top, Algo) ->
    if
        Top == twod ->   % if else to check if its 2d of imp 3d and in that case calculate nearest square and cube.
            
            K = math:sqrt(Num),
             L = trunc(math:floor(K)),
        
            PlaneSize = L*L,
            RowSize = trunc(math:sqrt(PlaneSize)),
            persistent_term:put(plane, PlaneSize),
            persistent_term:put(row, RowSize);
        Top == threed ->
             
            K = math:pow(Num,1/3),
            L = trunc(math:floor(K)),


            PlaneSize = L*L,
            RowSize = trunc(K),
            persistent_term:put(plane, PlaneSize),
            persistent_term:put(row, RowSize);
        true ->
            ok
    end,
    % initializing all variables required for computation 
    Node_list = [],    %will contain list of all pids spawned
    Neighbor_Map = #{}, %will contain list of neighbors
    Node_map = #{}, %will maintian the number of times the rumour is heard
    Rumour_map = #{}, %will tell if the actor has heard the rumour or not 
    Fin_List = [],  %will contain the actors that have heard rumour 10 times 
    Weights_map = #{}, %will tell if the actor has heard the rumour or not 
    Index_map = #{}, 
    Int = 0,
    SelfInt = 0,
    Nfl = Num,
    persistent_term:put(nfl,Nfl),
    % using persistant term to store all variables globally
    persistent_term:put(en, Int),

    persistent_term:put(map, Node_map),
    persistent_term:put(list, Node_list),
    persistent_term:put(rmap, Rumour_map),
    persistent_term:put(fin, Fin_List),
    persistent_term:put(neighbor, Neighbor_Map),
    persistent_term:put(weights, Weights_map),
    persistent_term:put(index, Index_map),
    register(sid, spawn(gossip, send_self, [])),
    if Top==twod ->
         O = math:sqrt(Num),
             P = trunc(math:floor(O)),
             Q = P*P,
            register(mid, spawn(gossip, master, [Q, Top, Algo, Q])),
            register(lastid, spawn(gossip, last, [Q]));
        Top == threed ->
              R = trunc(math:pow(Num,1/3)),
              
             S = trunc(math:floor(R)),
             T = S*S*S,
             
            register(mid, spawn(gossip, master, [T, Top, Algo, T])),
            register(lastid, spawn(gossip, last, [T]));
        true ->
            register(mid, spawn(gossip, master, [Num, Top, Algo, Num])),
            register(lastid, spawn(gossip, last, [Num]))
        end.


%__________________________________________________________Master Function_______________________________________________
%spawns the actors and and creates topoligies and neighbor maps according to the given input
master(Num, Top, Algo, Threshold) ->
    Node_list = persistent_term:get(list),
    Node_map = persistent_term:get(map),
    Rumour_map = persistent_term:get(map),
    Weights_map = persistent_term:get(weights),
    Neighbor_map = persistent_term:get(neighbor),
    Index_map = persistent_term:get(index),

    for( Num,Node_list,Node_map,Rumour_map,Weights_map,Neighbor_map,Index_map,Algo,Threshold,1,Top), 
    if
        Top == full ->
            receive
                {_Pid, Msg} ->
                    if
                        Msg == finished ->
                            io:format("Wieghts: ~p~n", [persistent_term:get(weights)]),
                            L = persistent_term:get(list),
                            [Head | _Tail] = L,
                            statistics(runtime),
                            statistics(wall_clock),
                            Head ! {self(), initial};
                        true ->
                            ok
                    end
            end;
        Top == line ->
            receive
                {_Pid, Msg} ->
                    if
                        Msg == finished ->
                            NL = persistent_term:get(list),
                            NM = persistent_term:get(neighbor),
                            create_neighbors(NL, NM, 1,Num),
                            receive
                                {_Message} ->
                                    NM2 = persistent_term:get(neighbor),
                                    io:format("Neighbors: ~p~n", [NM2]),
                                    L = persistent_term:get(list),
                                    [Head | _Tail] = L,
                                    statistics(runtime),
                                    statistics(wall_clock),
                                    Head ! {self(), initial}
                            end;
                        true ->
                            ok
                    end
            end;
        Top == twod ->
            receive
                {_Pid, Msg} ->
                    if
                        Msg == finished ->
                            setup2d(Num, 1, Threshold),
                            receive
                                {_Message} ->
                                    NM2 = persistent_term:get(neighbor),
                                    io:format("Neighbors: ~p~n", [NM2]),
                                    L = persistent_term:get(list),
                                    [Head | _Tail] = L,
                                    statistics(runtime),
                                    statistics(wall_clock),
                                    Head ! {self(), initial}
                            end;
                        true ->
                            ok
                    end
            end;
        Top == threed ->
            receive
                {_Pid, Msg} ->
                    if
                        Msg == finished ->
                            setup2d(Num, 1, Threshold),
                            receive
                                {_Message} ->
                                    setup3d(Num, 1, Threshold),
                                    receive
                                        {_Msg} ->
                                            % assign(Num, 1, Threshold),
                                            % receive
                                            %     {_Msg2} ->
                                            NM2 = persistent_term:get(neighbor),
                                            io:format("Neighbors: ~p~n", [NM2]),
                                            L = persistent_term:get(list),
                                            [Head | _Tail] = L,
                                            statistics(runtime),
                                            statistics(wall_clock),
                                            Head ! {self(), initial}
                                        % end
                                    end
                            end;
                        true ->
                            ok
                    end
            end;
        true ->
            ok
    end.

% Spawner function that spawns all actors and stores the pids of all actors in a list 
for(0,Node_list,Node_map,Rumour_map,Weights_map,Neighbor_map,Index_map,Algo,Threshold,Index,Top
) ->
    persistent_term:put(map, Node_map),
    persistent_term:put(list, Node_list),
    persistent_term:put(rmap, Rumour_map),
    persistent_term:put(weights, Weights_map),
    persistent_term:put(neighbor, Neighbor_map),
    persistent_term:put(index, Index_map),
    mid ! {self(), finished},
    ok;
for(N,Node_list,Node_map,Rumour_map,Weights_map,Neighbor_map,Index_map,Algo,Threshold,Index,Top) ->
    Pid = spawn(gossip, Algo, [Top, Threshold]),
    L = [Pid],
    M = #{Pid => 0},
    R = #{Pid => false},
    W = #{Pid => {Index, 1}},
    NM = #{Pid => []},
    I = #{Pid => Index},
    New_list = L ++ Node_list,
    New_map = maps:merge(M, Node_map),
    RNew_map = maps:merge(R, Rumour_map),
    WNew_map = maps:merge(W, Weights_map),
    NNew_map = maps:merge(NM, Neighbor_map),
    INew_map = maps:merge(I, Index_map),
    persistent_term:put(map, New_map),
    persistent_term:put(rmap, RNew_map),
    persistent_term:put(list, New_list),
    persistent_term:put(weights, WNew_map),
    persistent_term:put(index, INew_map),
    persistent_term:put(neighbor, WNew_map),

    for(N - 1,New_list,New_map,RNew_map,WNew_map,NNew_map,INew_map,Algo,Threshold,Index + 1,Top).

%A helper function to keep the actor running and not wait infinitely for messeges
send_self() ->
    receive
        {From, _Msg} ->
            From ! {self()}
    end,
    send_self().

% A function where all the process will end up after the size of the finished list reaches the total number of actors.
last(Num) ->
    Int = persistent_term:get(en),
    if
        Int == Num ->
            {_, Time1} = statistics(runtime),
            {_, Time2} = statistics(wall_clock),
            U1 = Time1 * 1000,
            U2 = Time2 * 1000,
            io:format(
                "Converged in ~p microseconds~n", 
                [ U2]
            );
        true ->
            ok
    end,
    receive
        {khatam} ->
            Mega_map = persistent_term:get(map),
            Nint = Int + 1,
            persistent_term:put(en, Nint)
        % io:format("Map: ~p~n", [Mega_map])
    end,
    last(Num).


%_________________________________________________________GOSSIP______________________________________________________________
% this is the function which is run by all actors and this is where the gossip algorithm runs. 
gossip(Top, Threshold) ->
     Fin_List = persistent_term:get(fin),
    L1 = persistent_term:get(list),
    RMap = persistent_term:get(rmap),
    % io:fwrite("~p~n", [Fin_List]),
    Bool = maps:find(self(), RMap), % checks it the actors has heard the rumour
    Check = lists:member(self(), Fin_List), % checks if the actor has finished running. 
    if
        Bool == {ok, true} ->
            % io:fwrite("~p",[Check]),
            if
                Check == false -> % if the actor has not terminated and has heard thr rumour the it sends the rumour to other random
                                    % neighbors. 
                    LL = persistent_term:get(list),
                    Rand = random_loop(self(), LL, Top),
                    Rand ! {self(), "rumour"};
                true ->
                    ok
            end;
        true ->
            ok
    end,

    receive 
        {_Mid, _Msg, initial} -> % this receives the initial messege from the master to start the rumour
            Map = persistent_term:get(map),
            {ok, Val} = maps:find(self(), Map),
            NVal = Val + 1,
            M = maps:update(self(), NVal, Map),
            persistent_term:put(map, M),

            RMap2 = persistent_term:get(rmap),
            R = maps:update(self(), true, RMap2),
            persistent_term:put(rmap, R);
        {_Id, _Msg} -> % this checks the incoming messege from other actors. 
            Map = persistent_term:get(map),
            {ok, Val} = maps:find(self(), Map),

            NVal = Val + 1, % After receiving the rumour it increases its own count of hearing the rumor by 1and stores it globally 
            M = maps:update(self(), NVal, Map),
            persistent_term:put(map, M),

            RMap2 = persistent_term:get(rmap), % after hearing the rumor it updates the rumour map with val true confirming that it has heard he rumor
            R = maps:update(self(), true, RMap2),
            persistent_term:put(rmap, R),

            if
                NVal < 10 -> % this call gossip again if the count is less than 10 
                            % else the actor is transferred to the finished list 
                    gossip(Top, Threshold);
                NVal == 10 ->
                    F_List = persistent_term:get(fin),
                    Boolean = lists:member(self(), F_List),
                    if
                        Boolean == false ->
                            FL = [self()],
                            F = F_List ++ FL,
                            persistent_term:put(fin, F);
                        true ->
                            ok
                    end;
                true ->
                    ok
            end

    after 1 -> 
        % sid ! {self(), "self"}

        F_List = persistent_term:get(fin),
        X = length(F_List),
        if % checks if the neighbors are converged in cas of line, 2d and Imp 3d
            Top == line orelse Top == twod orelse Top == threed ->
                Neighbor = persistent_term:get(neighbor),
                Is_key = maps:is_key(self(), Neighbor),

                Finlen = length(F_List),

                if
                    Is_key == true ->
                        if
                            Finlen =/= 0 ->
                                N_list = maps:get(self(), Neighbor),
                                Y = length(N_list),
                                converge(N_list, self(), Y,gossip);
                            % io:fwrite("~p\n",[K]);
                            true ->
                                d
                        end;
                    true ->
                        ok
                end;
            true ->
                ok
        end,
        if
            X == Threshold-> % if the length of finished list if equal to the number of actors then the actors terminate. 
                % io:format("Finished List: ~p~n", [F_List]),
                % Mega_map = persistent_term:get(map),
                % io:format("Map: ~p~n", [Mega_map]),
                lastid ! {khatam},
                exit("bas");
            true ->
                gossip(Top, Threshold)
        end
    end,
    gossip(Top, Threshold).

%______________________________________________________PUSH SUM___________________________________________________________
% this is the algo for push sum. 
push_sum(Top, Threshold) ->
 RMap = persistent_term:get(rmap),
    receive
        {_Id, initial} -> % checks the initial messege 
            Weights_map3 = persistent_term:get(weights),
            {S2, W2} = maps:get(self(), Weights_map3),
            NewS = S2 / 2,
            NewW = W2 / 2,
            Weights_map2 = maps:update(self(), {NewS, NewW}, Weights_map3),
            persistent_term:put(weights, Weights_map2),
            RMap2 = persistent_term:get(rmap),
            R = maps:update(self(), true, RMap2),
            persistent_term:put(rmap, R),
           

            Random_node = random_loop(self(), persistent_term:get(list), Top),
            Random_node ! {self(), NewS, NewW}; % initially sends the rumour to random neighbor with S and W values
        {_Pid, S, W} ->
            Weights_map3 = persistent_term:get(weights),
            {Pid_Sum, Pid_Weight} = maps:get(self(), Weights_map3),
            % io:fwrite("sum: ~p~n, Weight: ~p~n", [Pid_Sum, Pid_Weight]),
            NewSum = Pid_Sum + S,
            NewWeight = Pid_Weight + W,  % adds the S and W values of other actor and keeps half and sends half of the value. 

            if
                W /= 0.0 ->
                    Change = abs(NewSum / NewWeight - S / W),
                    Delta = math:pow(10, -10),
                    if
                        Change < Delta -> % checks if change < delta 
                            Node_map = persistent_term:get(map),
                            TermRound = maps:get(self(), Node_map),
                            Node_map2 = maps:update(self(), TermRound + 1, Node_map),
                            persistent_term:put(map, Node_map2);
                        true ->
                            Node_map = persistent_term:get(map),
                            Node_map2 = maps:update(self(), 0, Node_map),
                            persistent_term:put(map, Node_map2)
                    end,
                    Node_map3 = persistent_term:get(map),
                    TermRound2 = maps:get(self(), Node_map3),
                    if
                        TermRound2 == 3 -> % if change < delta for 3 time then adds the actor to the finished list. 
                            Fin_List = persistent_term:get(fin),
                            Fin_List2 = lists:append(Fin_List, [self()]),
                            persistent_term:put(fin, Fin_List2);
                        true ->
                            ok
                    end;
                true ->
                    ok
            end, 
            Weights_map2 = maps:update(self(), {NewSum, NewWeight}, Weights_map3),
            persistent_term:put(weights, Weights_map2),
            RMap2 = persistent_term:get(rmap),
            R = maps:update(self(), true, RMap2),
            persistent_term:put(rmap, R),
         
         % sends half to random actors. 
            Random_node = random_loop(self(), persistent_term:get(list), Top),
            Random_node ! {self(), NewSum / 2, NewWeight / 2}
       
    after 5 ->
        F_List = persistent_term:get(fin),
        X = length(F_List),
        if
            Top == line orelse Top == twod orelse Top == threed ->
                Neighbor = persistent_term:get(neighbor),
                Is_key = maps:is_key(self(), Neighbor),

                Finlen = length(F_List),

                if
                    Is_key == true ->
                        if
                            Finlen =/= 0 -> % checks if neighbors are converged. 
                                N_list = maps:get(self(), Neighbor),
                                Y = length(N_list),
                                K = converge(N_list, self(), Y,pushsum);
                            
                            true ->
                                d
                        end;
                    true ->
                        ok
                end;
            true ->
                ok
        end,
        if
            X == Threshold ->
               
                lastid ! {khatam},
                exit(bas);
            true ->
                push_sum(Top, Threshold)
        end
    end,
    push_sum(Top, Threshold).


%converge function that checks if all the neighbors have converged

converge(_, Node_id, 0,Algo) ->

    F_List = persistent_term:get(fin),
    Boolean = lists:member(Node_id, F_List),
    if
        Boolean == false ->
                if Algo == pushsum ->

                    FL = [Node_id],
                    F = F_List ++ FL,
                    persistent_term:put(fin, F);
                
                true ->
                    Map = persistent_term:get(map),
                    {ok, Val} = maps:find(self(), Map),

                    NVal = Val + 1,
                    if
                        NVal == 10 ->
                            F_List = persistent_term:get(fin),
                            Boolean = lists:member(self(), F_List),
                            if
                                Boolean == false ->
                                    FL = [self()],
                                    F = F_List ++ FL,
                                    persistent_term:put(fin, F);
                                true ->
                                    ok
                            end;
                        true ->
                            ok
                    end,
                    M = maps:update(self(), NVal, Map),
                    persistent_term:put(map, M),
                    % io:fwrite("~p", [M]),

                    RMap2 = persistent_term:get(rmap),
                    R = maps:update(self(), true, RMap2),
                    persistent_term:put(rmap, R)
                end;


                    
                
    true ->
        ok
end;

converge(N_list, Node_id, Len,Algo) ->
    F_list = persistent_term:get(fin),
    [Head | Tail] = N_list,

    Chk = lists:member(Head, F_list),
 
    if
        Chk == true ->
            converge(Tail, Node_id, Len - 1,Algo);
        true ->
            f
    end.


%__________________________________________TOPOLOGY________________________________________________________
%______IMPerfect 3D______________________________________________________
random3d(Pid, Node_list, Neighbors) ->
    Random_node = lists:nth(rand:uniform(length(Node_list)), Node_list),
    Bool = lists:member(Random_node, Neighbors),
    if
        Random_node == Pid ->
            random3d(Pid, Node_list, Neighbors);
        Bool == true ->
            random3d(Pid, Node_list, Neighbors);
        true ->
            Random_node
    end.
assign(0, Idx, Threshold) ->
    mid ! {"done2"},
    ok;
assign(Num, Index, Threshold) ->
    Node_list = persistent_term:get(list),
    Pid = lists:nth(Index, Node_list),
    Neighbor_Map = persistent_term:get(neighbor),
    Neighbors = maps:get(Pid, Neighbor_Map),

    Random_node = random3d(Pid, Node_list, Neighbors),
    N = lists:append(Neighbors, [Random_node]),
    Neighbor_map2 = maps:update(Pid, N, Neighbor_Map),
    persistent_term:put(neighbor, Neighbor_map2),
    if
        Index == Threshold ->
            Idx = Threshold + 1,
            assign(Num - 1, Idx, Threshold);
        true ->
            assign(Num - 1, Index + 1, Threshold)
    end.

setup3d(0, Idx, Threshold) ->
    mid ! {"done"},
    ok;
setup3d(Num, Index, Threshold) ->
    Node_list = persistent_term:get(list),
    Pid = lists:nth(Index, Node_list),

    Size = length(Node_list),

    PlaneSize = persistent_term:get(plane),
    RowSize = persistent_term:get(row),

    Calc = PlaneSize * (RowSize - 1),

    if
        Index > 0 andalso Index =< PlaneSize ->
            Down = down(Index, PlaneSize),
            Neighbor_Map = persistent_term:get(neighbor),
            Neighbors = maps:get(Pid, Neighbor_Map),
            DownNeighbor = lists:nth(Down, Node_list),
            N = lists:append(Neighbors, [DownNeighbor]),
            Neighbor_map2 = maps:update(Pid, N, Neighbor_Map),
            persistent_term:put(neighbor, Neighbor_map2);
        Index > Calc andalso Index =< Size ->
            Up = up(Index, PlaneSize),
            Neighbor_Map = persistent_term:get(neighbor),
            Neighbors = maps:get(Pid, Neighbor_Map),
            UpNeighbor = lists:nth(Up, Node_list),
            N = lists:append(Neighbors, [UpNeighbor]),
            Neighbor_map2 = maps:update(Pid, N, Neighbor_Map),
            persistent_term:put(neighbor, Neighbor_map2);
        true ->
            Down = down(Index, PlaneSize),
            Up = up(Index, PlaneSize),
            Neighbor_Map = persistent_term:get(neighbor),
            Neighbors = maps:get(Pid, Neighbor_Map),
            UpNeighbor = lists:nth(Up, Node_list),
            DownNeighbor = lists:nth(Down, Node_list),
            N = lists:append(Neighbors, [DownNeighbor]),
            N2 = lists:append(N, [UpNeighbor]),
            Neighbor_map2 = maps:update(Pid, N2, Neighbor_Map),
            persistent_term:put(neighbor, Neighbor_map2)
    end,
    if
        Index == Threshold ->
            Idx = Threshold + 1,
            setup3d(Num - 1, Idx, Threshold);
        true ->
            setup3d(Num - 1, Index + 1, Threshold)
    end.

up(Index, PlaneSize) ->
    Val = Index - PlaneSize,
    Val.

down(Index, PlaneSize) ->
    Val = Index + PlaneSize,
    Val.



%________________________________2D GRID__________________________________________
setup2d(0, Idx, Threshold) ->
    mid ! {"done"},
    ok;
setup2d(Num, Index, Threshold) ->
    Node_list = persistent_term:get(list),
    Pid = lists:nth(Index, Node_list),

    PlaneSize = persistent_term:get(plane),
    RowSize = persistent_term:get(row),

    East = east(Index, RowSize),
    West = west(Index, RowSize),
    North = north(Index, RowSize, PlaneSize),
    South = south(Index, RowSize, PlaneSize),

    if
        East /= -1 ->
            Neighbor_Map = persistent_term:get(neighbor),
            Neighbors = maps:get(Pid, Neighbor_Map),
            EastNeighbor = lists:nth(East, Node_list),
            N = lists:append(Neighbors, [EastNeighbor]),
            Neighbor_map2 = maps:update(Pid, N, Neighbor_Map),
            persistent_term:put(neighbor, Neighbor_map2);
        true ->
            ok
    end,
    if
        West /= -1 ->
            Neighbor_Map5 = persistent_term:get(neighbor),
            Neighbors5 = maps:get(Pid, Neighbor_Map5),
            WestNeighbor = lists:nth(West, Node_list),
            N5 = lists:append(Neighbors5, [WestNeighbor]),
            Neighbor_map25 = maps:update(Pid, N5, Neighbor_Map5),
            persistent_term:put(neighbor, Neighbor_map25);
        true ->
            ok
    end,
    if
        North /= -1 ->
            Neighbor_Map3 = persistent_term:get(neighbor),
            Neighbors3 = maps:get(Pid, Neighbor_Map3),
            NorthNeighbor = lists:nth(North, Node_list),
            N3 = lists:append(Neighbors3, [NorthNeighbor]),
            Neighbor_map23 = maps:update(Pid, N3, Neighbor_Map3),
            persistent_term:put(neighbor, Neighbor_map23);
        true ->
            ok
    end,
    if
        South /= -1 ->
            Neighbor_Map4 = persistent_term:get(neighbor),
            Neighbors4 = maps:get(Pid, Neighbor_Map4),
            SouthNeighbor = lists:nth(South, Node_list),
            N4 = lists:append(Neighbors4, [SouthNeighbor]),
            Neighbor_map24 = maps:update(Pid, N4, Neighbor_Map4),
            persistent_term:put(neighbor, Neighbor_map24);
        true ->
            ok
    end,

    setup2d(Num - 1, Index + 1, Threshold).

east(Index, RowSize) ->
    Mod = math:fmod(Index, RowSize),
    if
        Mod == 0 ->
            -1;
        true ->
            Index + 1
    end.

west(Index, RowSize) ->
    Mod = math:fmod(Index, RowSize),
    if
        Mod == 1 ->
            -1;
        true ->
            Index - 1
    end.

north(Index, RowSize, PlaneSize) ->
    Mod = math:fmod(Index, PlaneSize),
    if
        Mod >= 1 andalso Mod =< RowSize ->
            -1;
        true ->
            Index - RowSize
    end.

south(Index, RowSize, PlaneSize) ->
    Mod = math:fmod(Index, PlaneSize),
    Size = PlaneSize - RowSize + 1,
    if
        Mod >= Size andalso Mod =< PlaneSize ->
            -1;
        Mod == 0 ->
            -1;
        true ->
            Index + RowSize
    end.

%_______________________LINE____________________________________________________

create_neighbors(Node_list, Neighbor_Map, _,0) ->
    persistent_term:put(neighbor, Neighbor_Map),
    persistent_term:put(list, Node_list),
    mid ! {neighbors_finished},
    ok;
create_neighbors(Node_list, Neighbor_Map, Index,Num) ->
    if
        Index == 1 ->
            Key = lists:nth(Index, Node_list),
            Neighbor_List = maps:get(Key, Neighbor_Map),
            X = lists:nth(Index + 1, Node_list),
            L = [X],
            N_List = Neighbor_List ++ L,
            NM = maps:update(Key, N_List, Neighbor_Map),
            persistent_term:put(neighbor, NM);
        Index == length(Node_list) ->
            Key = lists:nth(Index, Node_list),
            Neighbor_List = maps:get(Key, Neighbor_Map),
            X = lists:nth(Index - 1, Node_list),
            L = [X],
            N_List = Neighbor_List ++ L,
            NM = maps:update(Key, N_List, Neighbor_Map),
            persistent_term:put(neighbor, NM);
        true ->
            Key = lists:nth(Index, Node_list),
            Neighbor_List = maps:get(Key, Neighbor_Map),
            X1 = lists:nth(Index + 1, Node_list),
            X2 = lists:nth(Index - 1, Node_list),
            L = [X1] ++ [X2],
            N_List = Neighbor_List ++ L,
            NM = maps:update(Key, N_List, Neighbor_Map),
            persistent_term:put(neighbor, NM)
    end,
    N_Map = persistent_term:get(neighbor),
    Node_L = persistent_term:get(list),
    create_neighbors(Node_L, N_Map, Index + 1,Num-1).

%_________________________________________________________________________________________
%function for getting random neighbors from the neighbor list. 
random_loop(Node_id, Node_list, Top) ->
    if
        Top == full ->
            Random_node = lists:nth(rand:uniform(length(Node_list)), Node_list),
            if
                Random_node == Node_id ->
                    random_loop(Node_id, Node_list, Top);
                true ->
                    Random_node
            end;
        Top == line orelse Top == twod orelse Top == threed ->
            Neighbor_Map = persistent_term:get(neighbor),
            Neighbor_List = maps:get(Node_id, Neighbor_Map),
            Random_node = lists:nth(rand:uniform(length(Neighbor_List)), Neighbor_List),

            if
                Random_node == Node_id ->
                    random_loop(Node_id, Node_list, Top);
                true ->
                    Random_node
            end;
        Top == threed ->
            Neighbor_Map = persistent_term:get(neighbor),
            Neighbor_List = maps:get(Node_id, Neighbor_Map),
            Random_node = lists:nth(rand:uniform(length(Neighbor_List)), Neighbor_List),
            R = random3d(Node_id, Node_list, Neighbor_List),
            Templist = [R, Random_node],
            RR = lists:nth(rand:uniform(length(Templist)), Templist),
            RR;
        true ->
            ok
    end.