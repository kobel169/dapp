module Dapp
  module Dimg
    module Build
      module Stage
        class BuildArtifact < Base
          def initialize(dimg)
            @prev_stage = GAArtifactPatch.new(dimg, self)
            @dimg = dimg
          end

          def empty?
            !dimg.builder.build_artifact?
          end

          def context
            [git_artifacts_dependencies, builder_checksum]
          end

          def builder_checksum
            dimg.builder.build_artifact_checksum
          end

          def prepare_image
            super do
              dimg.builder.build_artifact(image)
            end
          end
        end # BuildArtifact
      end # Stage
    end # Build
  end # Dimg
end # Dapp
