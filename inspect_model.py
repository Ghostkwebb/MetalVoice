import coremltools as ct
import numpy as np

try:
    model = ct.models.MLModel('DeepFilterNet3_Streaming.mlpackage')
    print("--- MODEL SPEC ---")
    print(model.get_spec().description)
    print("--- INPUTS ---")
    for i in model.input_description:
        print(f"Name: {i}")
        print(model.input_description[i])
    print("--- OUTPUTS ---")
    for o in model.output_description:
        print(f"Name: {o}")
        print(model.output_description[o])
except Exception as e:
    print(f"Error: {e}")
