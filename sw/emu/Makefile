CXXSTAGES_DIR = stages/c++
STAGES = $(CXXSTAGES_DIR)/test_vertices $(CXXSTAGES_DIR)/vertex_transform $(CXXSTAGES_DIR)/rasterizer $(CXXSTAGES_DIR)/illumination $(CXXSTAGES_DIR)/fragment_ops $(CXXSTAGES_DIR)/texturing
.PHONY: cxxstages $(STAGES)

cxxstages: $(STAGES)

$(STAGES):
	$(MAKE) -C $@
