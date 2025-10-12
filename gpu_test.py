import torch
print("cuda_available:", torch.cuda.is_available())
print("cuda_runtime:", torch.version.cuda)
if torch.cuda.is_available():
    print("device_count:", torch.cuda.device_count())
    print("device_name:", torch.cuda.get_device_name(0))

