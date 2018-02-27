class ArchivesSpaceService < Sinatra::Base

  Endpoint.post('/merge_requests/subject')
    .description("Carry out a merge request against Subject records")
    .params(["merge_request",
             JSONModel(:merge_request), "A merge request",
             :body => true])
    .permissions([:merge_subject_record])
    .returns([200, :updated]) \
  do
    target, victims = parse_references(params[:merge_request])

    ensure_type(target, victims, 'subject')

    Subject.get_or_die(target[:id]).assimilate(victims.map {|v| Subject.get_or_die(v[:id])})

    json_response(:status => "OK")
  end


  Endpoint.post('/merge_requests/agent')
    .description("Carry out a merge request against Agent records")
    .params(["merge_request",
             JSONModel(:merge_request), "A merge request",
             :body => true])
    .permissions([:merge_agent_record])
    .returns([200, :updated]) \
  do
    target, victims = parse_references(params[:merge_request])

    if (victims.map {|r| r[:type]} + [target[:type]]).any? {|type| !AgentManager.known_agent_type?(type)}
      raise BadParamsException.new(:merge_request => ["Agent merge request can only merge agent records"])
    end

    agent_model = AgentManager.model_for(target[:type])
    agent_model.get_or_die(target[:id]).assimilate(victims.map {|v|
                                                     AgentManager.model_for(v[:type]).get_or_die(v[:id])
                                                   })

    json_response(:status => "OK")
  end

  Endpoint.post('/merge_requests/agent_detail')
  .description("Carry out a detailed merge request against Agent records")
  .params(["dry_run", BooleanParam, "If true, don't process the merge, just display the merged record", :optional => true],
          ["merge_request_detail",
             JSONModel(:merge_request_detail), "A detailed merge request",
             :body => true])
  .permissions([:merge_agent_record])
  .returns([200, :updated]) \
  do
    target, victims = parse_references(params[:merge_request_detail])

    selections = parse_selections(params[:merge_request_detail].selections)


    if (victims.map {|r| r[:type]} + [target[:type]]).any? {|type| !AgentManager.known_agent_type?(type)}
      raise BadParamsException.new(:merge_request_detail => ["Agent merge request can only merge agent records"])
    end

    agent_model = AgentManager.model_for(target[:type])
    #agent_model = AgentManager.model_for(victims[0][:type])

    target = agent_model.get_or_die(target[:id]) 

    victim = agent_model.get_or_die(victims[0][:id])
    if params[:dry_run]
      target = agent_model.to_jsonmodel(target)
      victim = agent_model.to_jsonmodel(victim)
      new_target = merge_details(target, victim, selections)
      result = new_target
    else
      puts "\n\n\n\n\n\n"
      puts "hellloooo I made it!!!!!!!"
      puts "\n\n\n\n\n\n"
      target_json = agent_model.to_jsonmodel(target)
      victim_json = agent_model.to_jsonmodel(victim)
      new_target = merge_details(target_json, victim_json, selections)
      target.assimilate((victims.map {|v|
                                       AgentManager.model_for(v[:type]).get_or_die(v[:id])
                                     }))
      puts "\n\n\n\n\n\n"
      puts new_target
      puts "\n\n\n\n\n\n"

      target.update_from_json(new_target)
      puts "\n\n\n\n\n\n"
      puts target
      puts "\n\n\n\n\n\n"
      json_response(:status => "OK")
    end

    json_response(resolve_references(result, ['related_agents']))
  end

  Endpoint.post('/merge_requests/resource')
    .description("Carry out a merge request against Resource records")
    .params(["repo_id", :repo_id],
            ["merge_request",
             JSONModel(:merge_request), "A merge request",
             :body => true])
    .permissions([:merge_archival_record])
    .returns([200, :updated]) \
  do
    target, victims = parse_references(params[:merge_request])
    repo_uri = JSONModel(:repository).uri_for(params[:repo_id])

    check_repository(target, victims, params[:repo_id])
    ensure_type(target, victims, 'resource')

    Resource.get_or_die(target[:id]).assimilate(victims.map {|v| Resource.get_or_die(v[:id])})

    json_response(:status => "OK")
  end


  Endpoint.post('/merge_requests/digital_object')
    .description("Carry out a merge request against Digital_Object records")
    .params(["repo_id", :repo_id],
            ["merge_request",
             JSONModel(:merge_request), "A merge request",
             :body => true])
    .permissions([:merge_archival_record])
    .returns([200, :updated]) \
  do
    target, victims = parse_references(params[:merge_request])
    repo_uri = JSONModel(:repository).uri_for(params[:repo_id])

    check_repository(target, victims, params[:repo_id])
    ensure_type(target, victims, 'digital_object')

    DigitalObject.get_or_die(target[:id]).assimilate(victims.map {|v| DigitalObject.get_or_die(v[:id])})

    json_response(:status => "OK")
  end


  private

  def parse_references(request)
    target = JSONModel.parse_reference(request.target['ref'])
    victims = request.victims.map {|victim| JSONModel.parse_reference(victim['ref'])}

    [target, victims]
  end

  def check_repository(target, victims, repo_id)
    repo_uri = JSONModel(:repository).uri_for(repo_id)

    if ([target] + victims).any? {|r| r[:repository] != repo_uri}
      raise BadParamsException.new(:merge_request => ["All records to merge must be in the repository specified"])
    end
  end


  def ensure_type(target, victims, type)
    if (victims.map {|r| r[:type]} + [target[:type]]).any? {|t| t != type}
      raise BadParamsException.new(:merge_request => ["This merge request can only merge #{type} records"])
    end
  end

  def parse_selections(selections, path=[], all_values={})
    puts "\n\n\n\n\n\n\n"
    puts selections
    puts "\n\n\n\n\n\n\n"
    selections.each_pair do |k, v|
      path << k
      case v
        when String
          if v === "REPLACE"
            all_values.merge!({"#{path.join(".")}" => "#{v}"})
            path.pop
          else
            path.pop
            next
          end
        when Hash then parse_selections(v, path, all_values)
        when Array then v.each_with_index do |v2, index|
          path << index
          parse_selections(v2, path, all_values)
          path.pop
        end
        else 
          path.pop
          next
      end
    end
    path.pop

    return all_values
  end 

  def merge_details(target, victim, selections)
    puts "\n\n\n\n\n\n\n"
    puts selections
    puts "\n\n\n\n\n\n\n"
    selections.each_key do |key|
      path = key.split(".")
      path_fix = []
      path.each do |part|
        if part.length === 1
          part = part.to_i
        end
        path_fix.push(part)
      end
      path_fix_length = path_fix.length 
      if path_fix[0] != 'related_agents' && path_fix[0] != 'external_documents' && path_fix[0] != 'notes'
        case path_fix_length 
          when 1 
            target[path_fix[0]] = victim[path_fix[0]]
          when 2 
            target[path_fix[0]][path_fix[1]] = victim[path_fix[0]][path_fix[1]]
          when 3
            begin
              target[path_fix[0]][path_fix[1]][path_fix[2]] = victim[path_fix[0]][path_fix[1]][path_fix[2]]
            rescue
              if target[path_fix[0]] === []
                target[path_fix[0]].push(victim[path_fix[0]][path_fix[1]])
              end
            end
          when 4
            target[path_fix[0]][path_fix[1]][path_fix[2]][path_fix[3]] = victim[path_fix[0]][path_fix[1]][path_fix[2]][path_fix[3]]
          when 5
            begin
              target[path_fix[0]][path_fix[1]][path_fix[2]][path_fix[3]][path_fix[4]] = victim[path_fix[0]][path_fix[1]][path_fix[2]][path_fix[3]][path_fix[4]]
            rescue
              if target[path_fix[0]] === []
                target[path_fix[0]].push(victim[path_fix[0]][path_fix[1]])
              elsif target[path_fix[0]][path_fix[1]][path_fix[2]] === []
                target[path_fix[0]][path_fix[1]][path_fix[2]].push(victim[path_fix[0]][path_fix[1]][path_fix[2]][path_fix[3]])
              end
            end
        end
      elsif path_fix[0] === 'related_agents'
        target['related_agents'].push(victim['related_agents'][path_fix[1]])
      elsif path_fix[0] === 'external_documents'
        target['external_documents'].push(victim['external_documents'][path_fix[1]])
      elsif path_fix[0] === 'notes'
        target['notes'].push(victim['notes'][path_fix[1]])
      end
    target['title'] = target['names'][0]['sort_name']
    end
    target
  end


end
