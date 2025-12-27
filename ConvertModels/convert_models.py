#!/usr/bin/env python3
import argparse
from pathlib import Path
import yaml
import coremltools as ct
import torch
from transformers import AutoModel, AutoTokenizer, AutoModelForSequenceClassification, AutoModelForTokenClassification

SCRIPT_DIR = Path(__file__).parent
OUTPUT_DIR = SCRIPT_DIR / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

def load_config():
    with open(SCRIPT_DIR / "models.yaml") as f:
        return yaml.safe_load(f)

def get_model_class(model_type):
    """Map model type to HuggingFace class"""
    classes = {
        "embedding": AutoModel,
        "sequence_classification": AutoModelForSequenceClassification,
        "token_classification": AutoModelForTokenClassification,
    }
    return classes[model_type]

def convert_model(name, config):
    """Generic model converter"""
    print(f"\n{'='*60}")
    print(f"Converting {name}: {config['source']}")
    print(f"{'='*60}")
    
    # Load model and tokenizer
    print(f"📥 Loading {config['source']}...")
    tokenizer = AutoTokenizer.from_pretrained(
        config['source'],
        trust_remote_code=config.get('trust_remote_code', False)
    )
    model_class = get_model_class(config['type'])
    model = model_class.from_pretrained(
        config['source'],
        trust_remote_code=config.get('trust_remote_code', False)
    )
    model.eval()
    
    # Prepare inputs
    max_length = config.get('max_length', 512)
    inputs = tokenizer(
        "sample text",
        return_tensors="pt",
        padding=True,
        max_length=max_length
    )
    
    # Trace model
    print("🔧 Tracing model...")
    with torch.no_grad():
        # For classification models, wrap to return only logits
        if config['type'] in ['sequence_classification', 'token_classification']:
            class LogitsWrapper(torch.nn.Module):
                def __init__(self, model):
                    super().__init__()
                    self.model = model
                
                def forward(self, input_ids, attention_mask):
                    outputs = self.model(input_ids=input_ids, attention_mask=attention_mask)
                    return outputs.logits
            
            wrapped_model = LogitsWrapper(model)
            traced = torch.jit.trace(wrapped_model, (inputs['input_ids'], inputs['attention_mask']))
        else:
            traced = torch.jit.trace(model, (inputs['input_ids'], inputs['attention_mask']), strict=False)
    
    # Convert to CoreML
    print("🔄 Converting to CoreML...")
    convert_kwargs = {
        "inputs": [
            ct.TensorType(name="input_ids", shape=(1, max_length), dtype=int),
            ct.TensorType(name="attention_mask", shape=(1, max_length), dtype=int),
        ],
        "compute_units": ct.ComputeUnit.ALL,
    }
    
    # Add classifier config if labels provided
    if 'labels' in config:
        convert_kwargs['classifier_config'] = ct.ClassifierConfig(config['labels'])
    
    mlmodel = ct.convert(traced, **convert_kwargs)
    
    # Quantize if specified
    if config.get('quantize'):
        nbits = config['quantize']
        print(f"🗜️  Quantizing to {nbits}-bit...")
        mlmodel = ct.models.neural_network.quantization_utils.quantize_weights(
            mlmodel,
            nbits=nbits
        )
    
    # Save
    output_path = OUTPUT_DIR / config['output_name']
    mlmodel.save(str(output_path))
    
    # Report size
    size_mb = sum(f.stat().st_size for f in output_path.rglob('*') if f.is_file()) / (1024**2)
    print(f"✅ Saved to {output_path}")
    print(f"📦 Size: {size_mb:.1f} MB")

def main():
    parser = argparse.ArgumentParser(description="Convert HuggingFace models to CoreML")
    parser.add_argument("models", nargs="*", help="Model names to convert (default: all)")
    parser.add_argument("--list", action="store_true", help="List available models")
    args = parser.parse_args()
    
    config = load_config()
    available = config['models'].keys()
    
    if args.list:
        print("Available models:")
        for name in available:
            print(f"  - {name}")
        return
    
    # Determine which models to convert
    to_convert = args.models if args.models else available
    
    for name in to_convert:
        if name not in available:
            print(f"❌ Unknown model: {name}")
            print(f"Available: {', '.join(available)}")
            continue
        
        try:
            convert_model(name, config['models'][name])
        except Exception as e:
            print(f"❌ Failed to convert {name}: {e}")
            continue
    
    print(f"\n✅ Done! Drag .mlpackage files from PythonScripts/output/ into Xcode")

if __name__ == "__main__":
    main()
