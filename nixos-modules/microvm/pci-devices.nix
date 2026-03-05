{ config, lib, pkgs, ... }:
let
  pciDevices = builtins.filter ({ bus, ... }:
    bus == "pci"
  ) config.microvm.devices;

  inherit (config.microvm.runnerIdentity) runnerUser runnerGroup;
in
{
  microvm.binScripts.pci-setup = lib.mkIf (pciDevices != []) (''
    set -eou pipefail
    ${pkgs.kmod}/bin/modprobe vfio-pci
  '' + lib.concatMapStrings ({ path, ... }: ''
    cd /sys/bus/pci/devices/${path}
    if [ -e driver ]; then
      echo ${path} > driver/unbind
    fi
    echo vfio-pci > driver_override
    echo ${path} > /sys/bus/pci/drivers_probe
  '' +
  # In order to access the vfio dev the permissions must be set
  # for the user/group running the VMM later.
  #
  # Insprired by https://www.kernel.org/doc/html/next/driver-api/vfio.html#vfio-usage-example
  #
  # assert we could get the IOMMU group number (=: name of VFIO dev)
  ''
    [[ -e iommu_group ]] || exit 1
    VFIO_DEV=$(basename $(readlink iommu_group))
    echo "Making VFIO device $VFIO_DEV accessible for user"
    chown ${runnerUser}:${runnerGroup} /dev/vfio/$VFIO_DEV
  '') pciDevices);
}

