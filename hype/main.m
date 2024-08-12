//
//  main.m
//  hype
//
//  Created by Sanchit Sahay on 10/08/24.
//

#import <Foundation/Foundation.h>
#import <Foundation/NSURL.h>
#import <Virtualization/VZVirtualMachine.h>
#import <Virtualization/VZVirtualMachineConfiguration.h>
#import <Virtualization/VZVirtioConsoleDeviceSerialPortConfiguration.h>
#import <Virtualization/VZFileHandleSerialPortAttachment.h>
#import <Virtualization/VZBootLoader.h>
#import <Virtualization/VZLinuxBootLoader.h>
#import <Virtualization/VZVirtualMachineDelegate.h>
#import <Virtualization/VZUSBMassStorageDeviceConfiguration.h>
#import <Virtualization/VZDiskImageStorageDeviceAttachment.h>
#import <Virtualization/VZEFIVariableStore.h>
#import <Virtualization/VZVirtioBlockDeviceConfiguration.h>
#import <Virtualization/VZEFIBootLoader.h>
#import <termios.h>


@interface Delegate : NSObject
<VZVirtualMachineDelegate>
@end

@implementation Delegate

-(void) guestDidStopVirtualMachine:(VZVirtualMachine *)virtualMachine{
    printf("Guest did stop. Exiting.");
}

@end

VZSerialPortConfiguration* create_console_configuration(void) {
    
    VZVirtioConsoleDeviceSerialPortConfiguration *console_config = [VZVirtioConsoleDeviceSerialPortConfiguration alloc];
    
    NSFileHandle *input_file_handle = NSFileHandle.fileHandleWithStandardInput;
    NSFileHandle *output_file_handle = NSFileHandle.fileHandleWithStandardOutput;
    
    struct termios attributes;
    
    tcgetattr(input_file_handle.fileDescriptor, &attributes);
    attributes.c_iflag &= ~(tcflag_t) ICRNL;
    attributes.c_lflag &= ~(tcflag_t) ICANON | ECHO;
    tcsetattr(input_file_handle.fileDescriptor, TCSANOW, &attributes);
    
    VZFileHandleSerialPortAttachment *stdio_attachment = [[VZFileHandleSerialPortAttachment alloc ] initWithFileHandleForReading:input_file_handle fileHandleForWriting:output_file_handle];
    
    console_config.attachment = (VZSerialPortAttachment*) stdio_attachment;
    
    return console_config;
}

VZBootLoader* create_bootloader(void) {
    VZEFIBootLoader *bootloader = [VZEFIBootLoader alloc];
    
    // Create EFI Variable Store
    VZEFIVariableStore *efi_variable_store = [[VZEFIVariableStore alloc ] initCreatingVariableStoreAtURL:[[NSURL alloc] initFileURLWithPath:@"/Users/sanchitsahay/efi.store" isDirectory:false] options:VZEFIVariableStoreInitializationOptionAllowOverwrite error:NULL];

    bootloader.variableStore = efi_variable_store;
    return bootloader;
}

void vm_boot_error(NSError* vm_start_error) {
    NSLog(@"%@", [NSString stringWithFormat:@"Failed to start Virtual Machine %@", vm_start_error]);
    exit(EXIT_SUCCESS);
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        if(argc != 4) {
            NSLog(@"Usage: hype <> <kernel-path> <initial-ram-disk>");
            return 0;
        }
        
        NSURL *kernel_url = [NSURL fileURLWithFileSystemRepresentation:argv[1] isDirectory:false relativeToURL:NULL];
        
        // Create USB Storage with ISO.
        NSLog(@"Creating USB Storage with ISO");

        VZDiskImageStorageDeviceAttachment *attachment = [[VZDiskImageStorageDeviceAttachment alloc] initWithURL:kernel_url readOnly:true error:NULL];
        
        VZUSBMassStorageDeviceConfiguration *usb_storage = [[VZUSBMassStorageDeviceConfiguration alloc] initWithAttachment:attachment];
        
       
        
        // Create block device configuration
        NSLog(@"Creating Block device configuration");
        VZDiskImageStorageDeviceAttachment *attachment_block_dev = [[VZDiskImageStorageDeviceAttachment alloc] initWithURL:[[NSURL alloc] initFileURLWithFileSystemRepresentation:"/Users/sanchitsahay/block.dev" isDirectory:false relativeToURL:NULL] readOnly:false error:NULL ];
        
        VZVirtioBlockDeviceConfiguration *main_disk = [[VZVirtioBlockDeviceConfiguration alloc] initWithAttachment:attachment_block_dev];
        
        NSLog(@"Creating VM Configuration");
        VZVirtualMachineConfiguration *vm_config = [VZVirtualMachineConfiguration new];
        
        vm_config.CPUCount = VZVirtualMachineConfiguration.minimumAllowedCPUCount;
        vm_config.memorySize = VZVirtualMachineConfiguration.minimumAllowedMemorySize;
        
        NSArray<VZStorageDeviceConfiguration*> *disks = @[
           (VZStorageDeviceConfiguration*) main_disk,
           (VZStorageDeviceConfiguration*) usb_storage
        ];
        
        vm_config.storageDevices = disks;
        
        NSArray<VZSerialPortConfiguration*> *arr = @[create_console_configuration()];
        vm_config.serialPorts = arr;
        
        NSLog(@"Creating EFI Bootloader");
        vm_config.bootLoader = create_bootloader();
        
        NSError* config_error;
        [vm_config validateWithError:&config_error];
        
        if(config_error) {
            NSLog(@"%@", [NSString stringWithFormat:@"Error in configuration %@", config_error]);
        }
        
        
        VZVirtualMachine *vm = [[VZVirtualMachine alloc] initWithConfiguration:vm_config];
        
        Delegate *vm_delegate = [Delegate alloc];
        vm.delegate = vm_delegate;
        
        //    NSError* vm_start_error;
        NSLog(@"Starting Virtual Machine.");
        [vm startWithCompletionHandler:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"%@", [NSString stringWithFormat:@"%@%@", @"Virtual machine failed to start with ", error.localizedDescription]);
                exit(EXIT_SUCCESS);
            }
           
        }];
        
        while(true){
//            NSLog(@"In the while true loop?");
        }
        return 0;
    }
}


