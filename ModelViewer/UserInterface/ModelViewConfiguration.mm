//
//  ModelViewConfiguration.m
//  ModelViewer
//
//  Created by Dong on 2/25/18.
//  Copyright © 2018 middleware. All rights reserved.
//

#import "ModelViewConfiguration.h"
#import "NuoLua.h"

#include "NuoTableExporter.h"


@implementation ModelViewConfiguration
{
    NSString* _path;
    NSMutableDictionary* _devices;
}



- (instancetype)initWithFile:(NSString*)path
{
    self = [super init];
    
    if (self)
    {
        _path = path;
        [self load];
        
        if (!self.deviceName)
            [self initDeviceName];
        
        bool validDevice = false;
        NSString* highEndDevice = nil;
        
        _devices = [NSMutableDictionary new];
        NSArray* devices = MTLCopyAllDevices();
        for (id<MTLDevice> device in devices)
        {
            [_devices setObject:device forKey:device.name];
            if ([device.name isEqualToString:self.deviceName])
                validDevice = true;
            
            if (![device isLowPower] && !highEndDevice)
                highEndDevice = device.name;
        }
        
        // eGPU may be removed
        
        if (!validDevice)
            [self initDeviceName];
        
        // ignore low-end GPU if some high-end available
        
        if (self.device.isLowPower)
            _deviceName = highEndDevice;
        
        if (highEndDevice)
        {
            NSMutableArray* toDelete = [NSMutableArray new];
            for (NSString* deviceName in _devices.keyEnumerator)
            {
                if (((id<MTLDevice>)_devices[deviceName]).isLowPower)
                    [toDelete addObject:deviceName];
            }
            
            for (NSString* toDeleteOne in toDelete)
                [_devices removeObjectForKey:toDeleteOne];
        }
    }
    
    return self;
}


- (void)initDeviceName
{
    _deviceName = MTLCreateSystemDefaultDevice().name;
}


- (NSArray<NSString*>*)deviceNames
{
    return _devices.allKeys;
}


- (id<MTLDevice>)device
{
    return _devices[_deviceName];
}


- (void)load
{
    NSFileManager* manager = [NSFileManager defaultManager];
    BOOL isDir;
    BOOL exist = [manager fileExistsAtPath:_path isDirectory:&isDir];
    if (!exist || isDir)
        return;
    
    NuoLua* lua = [[NuoLua alloc] init];
    
    [lua loadFile:_path];
    
    [lua getField:@"windowFrame" fromTable:-1];
    
    _windowFrame.origin.x = [lua getFieldAsNumber:@"x" fromTable:-1];
    _windowFrame.origin.y = [lua getFieldAsNumber:@"y" fromTable:-1];
    _windowFrame.size.width = [lua getFieldAsNumber:@"w" fromTable:-1];
    _windowFrame.size.height = [lua getFieldAsNumber:@"h" fromTable:-1];
    
    [lua removeField];
    
    _deviceName = [lua getFieldAsString:@"device" fromTable:-1];
}


- (void)save
{
    NuoTableExporter exporter;
    
    exporter.StartTable();
    
    exporter.StartEntry("windowFrame");
    exporter.StartTable();
    
    {
        exporter.StartEntry("x");
        exporter.SetEntryValueFloat(_windowFrame.origin.x);
        exporter.EndEntry(false);
        
        exporter.StartEntry("y");
        exporter.SetEntryValueFloat(_windowFrame.origin.y);
        exporter.EndEntry(false);
        
        exporter.StartEntry("w");
        exporter.SetEntryValueFloat(_windowFrame.size.width);
        exporter.EndEntry(false);
        
        exporter.StartEntry("h");
        exporter.SetEntryValueFloat(_windowFrame.size.height);
        exporter.EndEntry(false);
    }
    
    exporter.EndTable();
    exporter.EndEntry(true);
    
    exporter.StartEntry("device");
    exporter.SetEntryValueString(_deviceName.UTF8String);
    exporter.EndEntry(true);
    
    exporter.EndTable();
    
    const std::string& content = exporter.GetResult();
    
    FILE* file = fopen(_path.UTF8String, "w");
    fwrite(content.c_str(), sizeof(char), content.length(), file);
    fclose(file);
}


@end
