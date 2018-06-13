module Dapp
  module Kube
    module Kubernetes
      # TODO endpoints can be gathered from api-server by api discovery.
      K8S_API_ENDPOINTS = {
        '1.6' => {
          '/api/v1' => [:service, :replicationcontroller, :pod, :podtemplate, ],
          '/apis/apps/v1beta1' => [:deployment, :statefulset, ],
          '/apis/extensions/v1beta1' => [:replicaset, :daemonset, ],
          '/apis/batch/v1' => [:job, ],
          '/apis/batch/v2aplha1' => [:cronjob, ],
        },
        '1.7' => {
          '/api/v1' => [:service, :replicationcontroller, :pod, :podtemplate, ],
          '/apis/apps/v1beta1' => [:deployment, :statefulset, ],
          '/apis/extensions/v1beta1' => [:replicaset, :daemonset, ],
          '/apis/batch/v1' => [:job, ],
          '/apis/batch/v2aplha1' => [:cronjob, ],
        },
        '1.8' => {
          '/api/v1' => [:service, :replicationcontroller, :pod, :podtemplate, ],
          '/apis/apps/v1beta2' => [:daemonset, :deployment, :replicaset, :statefulset, ],
          '/apis/batch/v1' => [:job, ],
          '/apis/batch/v1beta1' => [:cronjob, ],
        },
        '1.9' => {
          '/api/v1' => [:service, :replicationcontroller, :pod, :podtemplate, ],
          '/apis/apps/v1' => [:daemonset, :deployment, :replicaset, :statefulset, ],
          '/apis/batch/v1' => [:job, ],
          '/apis/batch/v1beta1' => [:cronjob, ],
        },
        '1.10' => {
          '/api/v1' => [:service, :replicationcontroller, :pod, :podtemplate, ],
          '/apis/apps/v1' => [:daemonset, :deployment, :replicaset, :statefulset, ],
          '/apis/batch/v1' => [:job, ],
          '/apis/batch/v1beta1' => [:cronjob, ],
        },
        'stable' => {
          '/api/v1' => [:service, :replicationcontroller, :pod, :podtemplate, ],
          '/apis/batch/v1' => [:job, ],
        },
      }

      class Client
        include Helper::YAML
        extend Helper::YAML

        ::Dapp::Dapp::Shellout::Base.default_env_keys << 'KUBECONFIG'

        #
        def initialize(namespace: nil)
          @namespace = namespace
          @query_parameters = {}
          @cluster_version
        end

        def namespace
          @namespace || self.class.kube_context_namespace(kube_context_config) || "default"
        end

        # Чтобы не перегружать методы явной передачей namespace.
        # Данный метод может пригодиться только в ситуации, когда надо указать другой namespace,
        # в большинстве случаев используется namespace из конструктора.
        def with_namespace(namespace, &blk)
          old_namespace = @namespace
          begin
            @namespace = namespace
            return yield
          ensure
            @namespace = old_namespace
          end
        end

        def with_query(query, &blk)
          old_query = @query_parameters
          begin
            @query_parameters = query
            return yield
          ensure
            @query_parameters = old_query
          end
        end

        # NOTICE: Название метода аналогично kind'у выдаваемого результата.
        # NOTICE: В данном случае в результате kind=DeploymentList.
        # NOTICE: Методы создания/обновления/удаления сущностей kubernetes заканчиваются на '!'. Например, create_deployment!.
        # В каждом методе происходит выбор api на основе версии кластера

        def resource_endpoint_path(resource)
          K8S_API_ENDPOINTS[cluster_version()].map do |path, resources|
            resources.include?(resource) ? path : nil
          end.compact.first
        end

        [
          :service, :replicationcontroller, :pod, :podtemplate,
          :daemonset, :deployment, :replicaset, :statefulset,
          :job,
          :cronjob,
        ].each do |resource|
          define_method :"#{resource}_list" do |**query_parameters|
            api_path = resource_endpoint_path(resource)
            request!(:get, "#{api_path}/namespaces/#{namespace}/#{resource}s", **query_parameters)
          end

          define_method resource do |name, **query_parameters|
            api_path = resource_endpoint_path(resource)
            request!(:get, "#{api_path}/namespaces/#{namespace}/#{resource}s/#{name}", **query_parameters)
          end

          define_method "#{resource}_status" do |name, **query_parameters|
            api_path = resource_endpoint_path(resource)
            request!(:get, "#{api_path}/namespaces/#{namespace}/#{resource}s/#{name}/status", **query_parameters)
          end

          define_method :"create_#{resource}!" do |spec, **query_parameters|
            api_path = resource_endpoint_path(resource)
            request!(:post, "#{api_path}/namespaces/#{namespace}/#{resource}s", body: spec, **query_parameters)
          end

          define_method :"replace_#{resource}!" do |name, spec, **query_parameters|
            api_path = resource_endpoint_path(resource)
            request!(:put, "#{api_path}/namespaces/#{namespace}/#{resource}s/#{name}", body: spec, **query_parameters)
          end

          define_method :"delete_#{resource}!" do |name, **query_parameters|
            api_path = resource_endpoint_path(resource)
            request!(:delete, "#{api_path}/namespaces/#{namespace}/#{resource}s/#{name}", **query_parameters)
          end

          define_method :"delete_#{resource}s!" do |**query_parameters|
            api_path = resource_endpoint_path(resource)
            request!(:delete, "#{api_path}/namespaces/#{namespace}/#{resource}s", **query_parameters)
          end

          define_method :"#{resource}?" do |name, **query_parameters|
            public_send(:"#{resource}_list", **query_parameters)['items'].map { |item| item['metadata']['name'] }.include?(name)
          end
        end


        def namespace_list(**query_parameters)
          request!(:get, '/api/v1/namespaces', **query_parameters)
        end

        def namespace?(name, **query_parameters)
          namespace_list(**query_parameters)['items'].map { |item| item['metadata']['name'] }.include?(name)
        end

        def create_namespace!(name, **query_parameters)
          request!(:post, '/api/v1/namespaces', body: { metadata: { name: name } }, **query_parameters)
        end

        def delete_namespace!(name, **query_parameters)
          request!(:delete, "/api/v1/namespaces/#{name}", **query_parameters)
        end

        # minikube returns empty major and minor. Fallback to stable only apis for minikube setup
        def cluster_version(**query_parameters)
          version_obj = request!(:get, "/version", **query_parameters)
          @cluster_version ||= begin
            major = version_obj['major']
            minor = version_obj['minor']
            k8s_version = "#{version_obj['major']}.#{version_obj['minor']}"
            if K8S_API_ENDPOINTS.has_key?(k8s_version)
              k8s_version
            else
              "stable"
            end
          end
        end

        def pod_log(name, follow: false, **query_parameters, &blk)
          excon_parameters = follow ? { response_block: blk } : {}
          request!(:get,
                   "/api/v1/namespaces/#{namespace}/pods/#{name}/log",
                   excon_parameters: excon_parameters,
                   response_body_parameters: {json: false},
                   **{ follow: follow }.merge(query_parameters))
        rescue Excon::Error::Timeout
          raise Error::Timeout
        rescue Error::Base => err
          if err.net_status[:code] == :bad_request and err.net_status[:data][:response_body]
            msg = err.net_status[:data][:response_body]['message']
            if msg.end_with? 'ContainerCreating'
              raise Error::Pod::ContainerCreating, data: err.net_status[:data]
            elsif msg.end_with? 'PodInitializing'
              raise Error::Pod::PodInitializing, data: err.net_status[:data]
            end
          end

          raise
        end

        def event_list(**query_parameters)
          request!(:get, "/api/v1/namespaces/#{namespace}/events", **query_parameters)
        end

        protected

        # query_parameters — соответствует 'Query Parameters' в документации kubernetes
        # excon_parameters — соответствует connection-опциям Excon
        # body — hash для http-body, соответствует 'Body Parameters' в документации kubernetes, опционален
        def request!(method, path, body: nil, excon_parameters: {}, response_body_parameters: {}, **query_parameters)
          with_connection(excon_parameters: excon_parameters) do |conn|
            request_parameters = {method: method, path: path, query: @query_parameters.merge(query_parameters)}
            request_parameters[:body] = JSON.dump(body) if body
            load_body! conn.request(request_parameters), request_parameters, **response_body_parameters
          end
        end

        def load_body!(response, request_parameters, json: true)
          response_ok = response.status.to_s.start_with? '2'

          if response_ok
            if json
              JSON.parse(response.body)
            else
              response.body
            end
          else
            err_data = {}
            err_data[:response_http_status] = response.status
            err_data[:response_raw_body] = response.body
            if response_body = (JSON.parse(response.body) rescue nil)
              err_data[:response_body] = response_body
            end
            err_data[:request_parameters] = request_parameters

            if response.status.to_s.start_with? '5'
              raise Error::Default, code: :server_error, data: err_data
            elsif response.status.to_s == '404'
              case err_data.fetch(:response_body, {}).fetch('details', {})['kind']
              when 'pods'
                raise Error::Pod::NotFound, data: err_data
              else
                raise Error::NotFound, data: err_data
              end
            elsif not response.status.to_s.start_with? '2'
              raise Error::Base, code: :bad_request, data: err_data
            end
          end
        end

        def with_connection(excon_parameters: {}, &blk)
          connection = begin
            Excon.new(kube_cluster_config['cluster']['server'], **kube_server_options(excon_parameters)).tap(&:get)
          rescue Excon::Error::Socket => err
            raise Error::ConnectionRefused,
                  code: :server_connection_refused,
                  data: { kube_cluster_config: kube_cluster_config, kube_user_config: kube_user_config, error: err.message }
          end

          return yield connection
        end

        def kube_server_options(excon_parameters = {})
          {}.tap do |opts|
            client_cert = kube_config.fetch('users', [{}]).first.fetch('user', {}).fetch('client-certificate', nil)
            opts[:client_cert] = client_cert if client_cert

            client_cert_data = kube_config.fetch('users', [{}]).first.fetch('user', {}).fetch('client-certificate-data', nil)
            opts[:client_cert_data] = Base64.decode64(client_cert_data) if client_cert_data

            client_key = kube_config.fetch('users', [{}]).first.fetch('user', {}).fetch('client-key', nil)
            opts[:client_key] = client_key if client_key

            client_key_data = kube_config.fetch('users', [{}]).first.fetch('user', {}).fetch('client-key-data', nil)
            opts[:client_key_data] = Base64.decode64(client_key_data) if client_key_data

            ssl_cert_store = OpenSSL::X509::Store.new
            if ssl_ca_file = kube_config.fetch('clusters', [{}]).first.fetch('cluster', {}).fetch('certificate-authority', nil)
              ssl_cert_store.add_file ssl_ca_file
            elsif ssl_ca_data = kube_config.fetch('clusters', [{}]).first.fetch('cluster', {}).fetch('certificate-authority-data', nil)
              ssl_cert_store.add_cert OpenSSL::X509::Certificate.new(Base64.decode64(ssl_ca_data))
            end
            opts[:ssl_cert_store] = ssl_cert_store

            opts[:ssl_ca_file] = nil

            opts[:middlewares] = [*Excon.defaults[:middlewares], Excon::Middleware::RedirectFollower]
            Excon.defaults[:ssl_verify_peer] = false
            opts.merge!(excon_parameters)
          end
        end

        def kube_user_config
          @kube_user_config ||= begin
            kube_user_config = self.class.kube_user_config(kube_config, kube_context_config['context']['user'])
            raise Error::BadConfig, code: :user_config_not_found, data: {config_path: self.class.kube_config_path, context: kube_context_config, user: kube_context_config['context']['user']} if kube_user_config.nil?
            kube_user_config
          end
        end

        def kube_cluster_config
          @kube_cluster_config ||= begin
            kube_cluster_config = self.class.kube_cluster_config(kube_config, kube_context_config['context']['cluster'])
            raise Error::BadConfig, code: :cluster_config_not_found, data: {config_path: self.class.kube_config_path, context: kube_context_config, cluster: kube_context_config['context']['cluster']} if kube_cluster_config.nil?
            kube_cluster_config
          end
        end

        def kube_context_config
          @kube_context_config ||= begin
            context_name = self.class.kube_context_name(kube_config)
            kube_context_config = self.class.kube_context_config(kube_config, context_name)
            raise Error::BadConfig, code: :config_context_not_found, data: {config_path: self.class.kube_config_path, config: kube_config, context_name: context_name} if kube_context_config.nil?
            kube_context_config
          end
        end

        def kube_config
          @kube_config ||= begin
            kube_config = self.class.kube_config(self.class.kube_config_path)
            raise Error::BadConfig, code: :config_not_found, data: { config_path: self.class.kube_config_path } if kube_config.nil?
            kube_config
          end
        end

        class << self
          def kube_config_path
            kube_config_path = ENV['KUBECONFIG']
            kube_config_path = File.join(ENV['HOME'], '.kube/config') unless kube_config_path
            kube_config_path
          end

          def kube_config(kube_config_path)
            yaml_load_file(kube_config_path) if File.exist?(kube_config_path)
          end

          def kube_context_name(kube_config)
            kube_config['current-context'] || begin
              if (context = kube_config.fetch('contexts', []).first)
                warn "[WARN] .kube/config current-context is not set, using context '#{context['name']}'"
                context['name']
              end
            end
          end

          def kube_context_config(kube_config, kube_context_name)
            kube_config.fetch('contexts', []).find {|context| context['name'] == kube_context_name}
          end

          def kube_user_config(kube_config, user_name)
            kube_config.fetch('users', []).find {|user| user['name'] == user_name}
          end

          def kube_cluster_config(kube_config, cluster_name)
            kube_config.fetch('clusters', []).find {|cluster| cluster['name'] == cluster_name}
          end

          def kube_context_namespace(kube_context_config)
            kube_context_config['context']['namespace']
          end
        end
      end # Client
    end # Kubernetes
  end # Kube
end # Dapp
