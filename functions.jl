#=
functions:
- Julia version: 1.9.3
- Author: Way1and
- Date: 2023-11-03
=#

include("./models.jl")
include("./handlers.jl")

import Printf

function init(P :: Parameters)
    R = RandomNGs(P)
    system = State()
    t0 = 0.0

    event_push!(system,  Arrival(1, t0))

    # add a problem at time 4.0
    t1 = 4.0
    event_push!(system, Problem(2, t1))
    return (system, R)
    end

  
# function to create output filenames

function output_files(P::Parameters)
    dir = pwd() * "/data/" *
      "/seed" * string(P.seed)*
      "/n_checkouts" * string(P.checkout_num) *
      "/mean_interarrival" * string(P.interarrival_time_mean) *
      "/mean_service" * string(P.service_time_mean) *
      "/mean_interproblem" * string(P.interproblem_time_mean) *
      "/mean_resolution" * string(P.resolution_time_mean) *
      "/final_time" * string(P.final_at) 
    file_entities = dir * "/entities.csv"
    file_state = dir * "/state.csv" 
    println(file_entities,file_state)

    return file_entities, file_state, dir
end

# functions to write output
# entity based instrumentation
function write_entity(fid::IO, customer::Customer)
    println(fid, "$(customer.id),$(customer.arrival_at),$(customer.service_start_at),$(customer.service_end_at),$(customer.problem_count)")
end

# event based instrumentation
function write_state(fid::IO,state::State, event::Event)
    println(fid, "$(event.id),$(event.customer_id),$(event.at),$(typeof(event)),$(length(state.waiting_queue)),$(length(state.servicing_queue) + length(state.problem_queue)),$(length(state.problem_queue))")
end

# function to create output and run the simulation
function  run_checkout_sim(P::Parameters)
    # initialise the system:
    (S, R) = init(P)
    
    # file directory and name; * concatenates strings.
    file_entities, file_state, dir = output_files(P)
    
    # create directory and output files
    mkpath(dir)
    fid_entities = open(file_entities, "w") # open the file for writing
    fid_state = open(file_state, "w")       # open the file for writing
    
    # print metadata to both outputs
    println(fid_entities, "# seed = $(P.seed)")
    println(fid_entities, "# n_checkouts = $(P.checkout_num)")
    println(fid_entities, "# mean_interarrival = $(P.interarrival_time_mean)")
    println(fid_entities, "# mean_service_time = $(P.service_time_mean)")
    println(fid_entities, "# mean_interproblem = $(P.interproblem_time_mean)")
    println(fid_entities, "# mean_mean_resolution = $(P.resolution_time_mean)")
    println(fid_entities, "# final_time = $(P.final_at)")
    println(fid_entities, "customer_ID,arrival_time,service_time,departure_time,no_problems")
    
    println(fid_state, "# seed = $(P.seed)")
    println(fid_state, "# n_checkouts = $(P.checkout_num)")
    println(fid_state, "# mean_interarrival = $(P.interarrival_time_mean)")
    println(fid_state, "# mean_service_time = $(P.service_time_mean)")
    println(fid_state, "# mean_interproblem = $(P.interproblem_time_mean)")
    println(fid_state, "# mean_mean_resolution = $(P.resolution_time_mean)")
    println(fid_state, "# final_time = $(P.final_at)")
    println(fid_state, "event_ID,customer_ID,time,event,n_waiting,n_checkout,n_problems")

    
    # main event loop 
    run!(S, P, R, fid_state, fid_entities)
    
    # remember to close the files
    close(fid_entities)
    close(fid_state)
end

# funtion to create event loop
function run!(system::State, P::Parameters, R::RandomNGs, fid_state::IO, fid_entities::IO)
    print_info_start(system, P)
    start_ts = time()
   
    # main event loop 
    problem_unset_queue = Queue{Problem}()  # 队列 全局待发生的问题
    while system.current_at < P.final_at
        # grab the next event from the event queue
        event = dequeue!(system.event_queue)
        # update the system based on the next event, and spawn new events. 
        # return arrived/departed customer.

        customer = update!(system, P, R, event)

        if customer === nothing
            # 保存 该 problem 事件 id
            enqueue!(problem_unset_queue, event)
            continue    
        end

        # 如果 服务队列变化
        if isa(event, Union{Arrival, Departure, Resolved}) 
            # 如果是离开 写入 实体
            if isa(event, Departure)
                write_entity(fid_entities, customer)
            end
            
            # 可以加入problem: 系统服务队列有人, 有未设置的问题
            if length(system.servicing_queue) != 0 && length(problem_unset_queue) != 0
                problem = dequeue!(problem_unset_queue)  # 出队 等待添加的问题
                problem.at = event.at + eps()  # 设置很小的时间间隔
                event_push!(system, problem, problem.id)  # 添加 问题事件 
            end
        end
        
        # write out data
        write_state(fid_state,system, event)
        println("    $event")
        # note that we are writing out the state AFTER each ARRIVAL
    end
   print_info_end(system, start_ts)
end

function print_info_end(system ::State, start_ts :: Float64)
    customer_count = system.customer_count
    event_count = system.event_count
    end_ts = time()
    run_time =round((end_ts - start_ts)*1000, digits = 3)  # 计算 运行时间
    
    println("
    \n OK!  
    cost: $run_time ms
    $event_count events occured.
    $customer_count entities built up.
    ")
end

function print_info_start(S ::State, P ::Parameters)
       
    println("
    \nSimulation Start.
    conditions: $P
    ")

end