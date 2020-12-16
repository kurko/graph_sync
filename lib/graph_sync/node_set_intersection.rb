module GraphSync
  # This object receives 2 lists of resources (e.g ad groups, ads etc) such as:
  #
  #   1) [ OpenStruct(remote_id: 1,   status: "created"),
  #        OpenStruct(remote_id: 2,   status: "paused"),
  #        OpenStruct(remote_id: 3,   status: "deleted") ]
  #
  #   2) [ OpenStruct(remote_id: 2,   status: "enabled"),
  #        OpenStruct(remote_id: 3,   status: "paused"),
  #        OpenStruct(remote_id: nil, status: "enabled"),
  #        OpenStruct(remote_id: nil, status: "paused") ]
  #
  # In the example above, according to the second resource,
  #
  #   remote_id: 1   - needs to be deleted
  #   remote_id: 2   - needs to be enabled
  #   remote_id: 3   - needs to be paused
  #   remote_id: nil (enabled) - needs to be created
  #   remote_id: nil (paused) - will not be created
  #
  class NodeSetIntersection
    def initialize(set_a:, set_b:, id_attr:)
      @new_resource = Array(set_a)
      @existing_resource = set_b
      @id_field = id_attr
    end

    # These are the objects that should remain enabled after operations of
    # pausing or creating, or when they're already enabled and shouldn't be
    # touched.
    #
    # We use this to decide whether something should be processed or not. For
    # example, when analyzing an ad group, it might already be enabled and we
    # would normally not process it. But then maybe some of its children objects
    # (e.g ad) was paused and we need to process it. All objects returned here
    # should be processed.
    def remain_enabled
      initial_candidate =
        @new_resource -
        Array(to_disable) -
        Array(to_pause) -
        Array(to_delete)
      initial_candidate.select { |n| status(n) == "enabled" }
    end

    def to_create_in_b
      new_resource.select do |n|
        no_remote_counterpart = existing_resource.none? { |existing|
          existing.public_send(id_field) == n.public_send(id_field)
        }

        is_enabled = status(n) == "enabled"

        # No :remote_id or no record on the remote end.
        is_enabled && (!n.public_send(id_field) || no_remote_counterpart)
      end
    end

    def to_pause
      pending_mutation("paused")
    end

    def to_enable
      pending_mutation("enabled")
    end

    def to_delete
      existing_resource
        .select { |e| !["deleted", "removed", "disabled"].include?(status(e)) }
        .select { |e| !new_ids.include?(e.public_send(id_field)) }
    end

    def to_disable
      to_delete
    end

    # - elements that have an ID but are not present in the remote service
    def conflicting
      new_resource
        .select { |n| n.public_send(id_field) }
        .select { |n| !existing_ids.include?(n.public_send(id_field)) }
    end

    private

    attr_reader :existing_resource, :new_resource, :id_field

    def pending_mutation(new_state)
      new_resource
        .select { |n| n.public_send(id_field) }
        .select { |n| status(n) == new_state }
        .select do |n|
          existing_resource.find do |e|
            e.public_send(id_field) == n.public_send(id_field) &&
              status(e) != new_state
          end
        end
    end

    def existing_ids
      @existing_ids ||= existing_resource.map(&id_field)
    end

    def new_ids
      @new_ids ||= new_resource.map(&id_field)
    end

    def status(resource)
      resource.respond_to?(:status) && resource.status.downcase
    end
  end
end
