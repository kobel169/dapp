module Dapp
  module Builder
    class Base
      attr_reader :conf

      # TODO Describe stages sequence with
      # TODO   ordering data
      # TODO Generate stages related methods
      # TODO   from that data

      def initialize(conf)
        @conf = conf
      end

      def run
        if prepare?
          prepare!
          infra_install!
          sources_1!
          infra_setup!
          app_install!
          app_setup!
        elsif infra_install?
          infra_install!
          sources_1!
          infra_setup!
          app_install!
          app_setup!
        elsif infra_setup?
          infra_setup!
          app_install!
          sources_2!
          app_setup!
        elsif app_install?
          app_install!
          sources_2!
          app_setup!
        elsif app_setup?
          app_setup!
          sources_3!
          sources_4!
        end
      end

      def build_stage!(from:, stage:)
        raise
      end

      def build_docker_image!(from:, cmd: [], tag:)
        # запустить команды в новом контейнере через docker run
        # сделать docker commit
        # удалить контейнер
      end


      def prepare?
        raise
      end

      def prepare!
        build_stage!(from: conf.from, stage: :prepare)
      end

      def prepare
        # запуск shell-команд из conf
      end

      def prepare_key
        # hash от shell-команд
      end


      def infra_install?
        raise
      end

      def infra_install!
        build_stage!(from: prepare_key, stage: :infra_install)
      end

      def infra_install
        raise
      end

      def infra_install_key
        raise
      end


      def infra_setup?
        raise
      end

      def infra_setup!
        build_stage!(from: sources_1_key, stage: :infra_setup)
      end

      def infra_setup
        raise
      end

      def infra_setup_key
        raise
      end


      def app_install?
        raise
      end

      def app_install!
        build_stage!(from: infra_setup_key, stage: :app_install)
      end

      def app_install
        raise
      end

      def app_install_key
        raise
      end


      def app_setup?
        raise
      end

      def app_setup!
        build_stage!(from: app_install_key, stage: :app_setup)
      end

      def app_setup
        raise
      end

      def app_setup_key
        raise
      end


      def sources_1
        raise
      end

      def sources_1!
        build_stage!(from: infra_install_key, stage: :sources_1)
      end

      def sources_1_key
        raise
      end


      def sources_2
        raise
      end

      def sources_2!
        build_stage!(from: app_install_key, stage: :sources_2)
      end

      def sources_2_key
        raise
      end


      def sources_3
        raise
      end

      def sources_3!
        build_stage!(from: app_setup_key, stage: :sources_3)
      end

      def sources_3_key
        raise
      end


      def sources_4
        raise
      end

      def sources_4!
        build_stage!(from: sources_3_key, stage: :sources_4)
      end

      def sources_4_key
        raise
      end
    end
  end
end