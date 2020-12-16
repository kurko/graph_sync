module GraphSync
  # Imagine that there are 2 graphs, ours and Facebook's, each one with nodes
  # of type:
  #
  # - campaign
  # - adsets
  # - ads
  # - creatives
  #
  # We need to make both's attributes equal. When the local node for AdsetA
  # changes its budget value, we need to update the remote corresponding node
  # to the same value. How can we know what attributes need to be updated
  # remotely?
  #
  # This class computes that.
  #
  # == Examples ==
  #
  # Node A and B are objects. You instantiate this class with something like
  # this:
  #
  #     GraphSync::NodesDiff.new(
  #       node_a: campaign_model,
  #       node_b: remote_campaign,
  #       rules: rules
  #     )
  #
  # Above, the class will compare A (a local model, e.g ::Campaign) and B
  # (an object representing a campaign remotely, e.g ::Facebook::Campaign).
  #
  # The following would check whether `#daily_budget` on A is different to
  # `#budget_amount` on B.
  #
  # [
  #   {
  #     node_a_attr: :daily_budget,
  #     node_b_attr: :budget_amount,
  #     canonical_node: :node_a,
  #   }
  # ]
  #
  # You can use a Proc to define how the values are checked for equality.
  # The following will call a class that is a dictionary of possible states.
  #
  # [
  #   {
  #     node_a_attr: :daily_budget,
  #     node_b_attr: :budget_amount,
  #     canonical_node: :node_a,
  #     diff_if: ->(a, b) {
  #       state = RemoteAdService::StateDictionary.new(b.status).local_name
  #       state != a.state
  #     }
  #   }
  # ]
  class NodesDiff
    # == Params ==
    #
    # - node_a: this is an object representing a node in the local graph,
    #   like an instance of `::Campaign`, `::AdGroup` and `::Ad`.
    #
    # - node_b: this is an object representing a node in the remote graph,
    #   like an instance of `::AdWords::Campaign::Response` and
    #   `::Facebook::AdGroup::Response`.
    #
    # - rules: this defines what local attributes match to what remote
    #   attributes, in the format,
    #
    #   These are the params for `rules:`:
    #
    #   - node_a_attr: what is the name of the attribute in a?
    #   - node_b_attr: what is the name of the attribute in b?
    #   - canonical_node: which node is the source of truth? When `:node_a` then
    #     :node_b will be updated, and vice versa.
    #   - diff_if (Proc.new(a, b)): this proc will be used for checking whether
    #     the attributes are different. They will be considered different if
    #     this returns `true`.
    def initialize(node_a:, node_b:, rules:, id_attr: :id)
      @node_a, @node_b, @rules = node_a, node_b, rules
    end

    # Returns a hash with the attributes that need to be updated on node a.
    # Given two objects (e.g ::Campaign and AdWords::Campaign::Response),
    # it will call methods on both objects according to the spec in `rules`,
    # and figure out what needs to be updated.
    def to_update_on_a
      @rules.each_with_object({}) do |rule, changes|
        changes.merge!(to_update_on_n(rule, :a))
      end
    end

    # Returns a hash with the attributes that need to be updated on node b.
    # Given two objects (e.g ::Campaign and AdWords::Campaign::Response),
    # it will call methods on both objects according to the spec in `rules`,
    # and figure out what needs to be updated.
    def to_update_on_b
      @rules.each_with_object({}) do |rule, changes|
        changes.merge!(to_update_on_n(rule, :b))
      end
    end

    private

    def validate_rule(rule)
      a_is_canonical?(rule) ||
        b_is_canonical?(rule) ||
        raise("No canonical: #{rule}")

      unless @node_a.respond_to?(rule[:node_a_attr])
        raise("Node :a (#{@node_a.class}) doesn't respond to #{rule[:node_a_attr]}")
      end
      unless @node_b.respond_to?(rule[:node_b_attr])
        raise("Node :b (#{@node_b.class}) doesn't respond to #{rule[:node_b_attr]}")
      end

      (rule[:node_a_attr] && rule[:node_b_attr]) || raise("No node attr defined")
    end

    def to_update_on_n(rule, node_name)
      changes = {}

      validate_rule(rule)

      if diff_values?(rule)
        if node_name == :b && a_is_canonical?(rule)
          changes[rule[:node_b_attr]] = node_value(:a, rule)
          changes[:id] = @node_b.public_send(:id) if @node_b.respond_to?(:id)
        elsif node_name == :a && b_is_canonical?(rule)
          changes[rule[:node_a_attr]] = node_value(:a, rule)
          changes[:id] = @node_a.public_send(:id) if @node_a.respond_to?(:id)
        end
      end

      changes
    end

    def a_is_canonical?(rule)
      rule.fetch(:canonical_node) == :node_a
    end

    def b_is_canonical?(rule)
      rule.fetch(:canonical_node) == :node_b
    end

    def diff_values?(rule)
      if rule[:diff_if].respond_to?(:call)
        rule[:diff_if].call(@node_a, @node_b)
      else
        node_value(:a, rule) != node_value(:b, rule)
      end
    end

    def node_value(node_name, rule)
      node_attr = rule[:"node_#{node_name}_attr"]
      if node_name == :a
        @node_a.public_send(node_attr.to_sym)
      else
        @node_b.public_send(node_attr.to_sym)
      end
    end
  end
end
