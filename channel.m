% Channel Transmission Flow Diagram
% +--------------+    +--------+    +--=-------+    +----+    +--+
% |[0, M-1] input| => |Modulate| => | + Pilots | => |IDFT| => |CP| => TX
% +--------------+    +--------+    +----------+    +----+    +--+
%       +--+    +---+    +----------+    +----------+    +---------------+
% RX => |CP| => |DFT| => | - Pilots | => |Demodulate| => |[0, M-1] output| 
%       +--+    +---+    +----------+    +----------+    +---------------+
classdef channel < matlab.mixin.Copyable
    properties (Constant)
        PLOC = 100 % every n bits a pilot is placed
        M = 4 % Modulation size
        LEN = 1000 % length of input data
        
        %{
        S = 10 %Rayleigh channel sampling rate (was 1e-3)
        % Frequency selective channel with 4 taps 
        D = [0, 1e-5, 3.5e-5, 12e-5, 15e-5] %Channel path delays
        P = [1, -1, -1, -3, -3] %Channel path gain (dB)
        %}

        S = 1e4 % 1000 Hz
        % Frequency selective channel with 4 taps 
        % delay should be significantly smaller than a period (1/1000)
        D = [0, 1e-8, 3.5e-8, 12e-8, 15e-8] %Channel path delays
        P = [0, -1, -1, -3, -3] %Channel path gain (dB)
    end
    properties
        % channels
        rayleigh_channel
        awgn_channel

        % channel properties 
        snr
        path_gains
        
        % pilot information
        pilot_locs
        message_locs
        tx_pilots
        rx_pilots

        % data flows in order from top to bottom of list. 
        % TX:
        input_data
        modulated_data
        pilot_data
        IDFT_data
        prefixed_data %skipping this for now
        % Channel:
        split_tap_data
        channel_output_data
        joined_tap_data
        % RX:
        un_prefixed_data % skipping this for now
        output_DFT_data
        no_pilot_data
        demodulated_data % output data
    end
    methods
        %% Master method
        function Obj = runRayleighChannel(Obj, MDS, SNR, param)
            if ~exist('param', 'var')
                param = "false";
            end
            % Create Rayleigh and AWGN channel (currently not showing plots
            % of channels). 
            Obj = Obj.create_channel(MDS, "false");
            Obj = Obj.create_gaussian_noise(SNR);

            % 1
            Obj.input_data = Obj.GenerateInput();
            % 2
            Obj.modulated_data = Obj.modulateQAM4(Obj.input_data);

            if param == "visualise"
                Obj.vis_QAM_clean();
            end

            % 3
            [Obj, Obj.pilot_data] = Obj.InsertPilots(Obj.modulated_data);

            % 4
            Obj.IDFT_data = Obj.IDFT(Obj.pilot_data);
            % 5
            [Obj, Obj.channel_output_data] = Obj.passThroughChannel(Obj.IDFT_data);

            % 6
            Obj.output_DFT_data = Obj.DFT(Obj.channel_output_data);

            if param == "visualise"
                Obj.vis_QAM_dirty();
            end

            % 7
            [Obj, Obj.no_pilot_data] = Obj.RemovePilots(Obj.output_DFT_data);

            if param == "visualise"
                Obj.vis_QAM_no_pilots_dirty();
            end

            % 8
            Obj.demodulated_data = Obj.demodulateQAM4(Obj.no_pilot_data);
        end

        %% Visualisation methods
        function vis_QAM_clean(Obj)
            scatterplot(Obj.modulated_data)
            title('4-QAM, Modulated data before rayleigh effect')
        end
        function vis_QAM_dirty(Obj)
            scatterplot(Obj.output_DFT_data)
            title('4-QAM, Modulated data after rayleigh effect')
        end
        function vis_QAM_no_pilots_dirty(Obj)
            scatterplot(Obj.no_pilot_data);
            title('4-QAM, Modulated data with rx_pilots removed');
        end
        %% Transmission to Reception
        % set the binary input
        function data = GenerateInput(Obj)
            data = randi([0, Obj.M-1], Obj.LEN, 1); 
            %Return data
        end
        function [Obj, pilot_data] = InsertPilots(Obj, modulated_data)
            pilot = 1; % pilot value is 1
            data = modulated_data;
            % Inserting pilots itteratively
            i = 1;
            while i <= length(data)
                if mod(i, Obj.PLOC) == 0
                    temp_lhs = data(1:i-1);
                    temp_rhs = data(i:end);
                    data = cat(1, temp_lhs, pilot ,temp_rhs); 
                    Obj.tx_pilots = cat(1, Obj.tx_pilots, pilot);
                    Obj.pilot_locs = cat(1, Obj.pilot_locs, i);
                else
                    Obj.message_locs = cat(1, Obj.message_locs, i);
                end
                i = i + 1;
            end
            pilot_data = data;
        end
        function [Obj, no_pilot_data] = RemovePilots(Obj, output_DFT_data)
            data = output_DFT_data;
            i = length(data);
            while i > 0
                if mod(i, Obj.PLOC) == 0
                    Obj.rx_pilots = cat(1, Obj.rx_pilots, data(i));
                    data(i) = [];
                end
                i = i - 1;
            end
            no_pilot_data = data;
        end
        % Modulate and Demodulate the binary data using QAM-4 modulation
        % into 4 channels (taps) for rayleigh channel transmission. 
        function modulated_data = modulateQAM4(Obj, input_data)
            % unit average power is true here and in AWGN channel
            modulated_data = qammod(input_data, 4, 'UnitAveragePower', true);
            %return modulated_data
        end
        function demodulated_data = demodulateQAM4(Obj, no_pilot_data)
            demodulated_data = qamdemod(no_pilot_data, 4);
            %return Obj
        end
        % Perform IDFT and DFT on modulated data
        function IDFT_data = IDFT(Obj, pilot_data)
            IDFT_data = ifft(pilot_data);
        end    
        function output_DFT_data = DFT(Obj, channel_output_data)
            output_DFT_data = fft(channel_output_data);
        end
        % Add CP (not implemented)
        function Obj = addCyclicPrefix(Obj)
            % not implemented currently
        end
        % Remove CP (not implemented)
        function Obj = removeCyclicPrefix(Obj)
            % not implemented currently
        end
        % Function to process signals through the rayleigh channel
        function [Obj, channel_output_data] = passThroughChannel(Obj, IDFT_data)
            [channel_output_data, Obj.path_gains] = Obj.rayleigh_channel(IDFT_data);
            %Obj.channel_output_data = Obj.rayleigh_channel(Obj.IDFT_data);
            channel_output_data = Obj.awgn_channel(channel_output_data);
            %Obj.channel_output_data = Obj.IDFT_data;
            %return Obj
        end
        %% Creating the channels
        % Create rayleigh channel from given maximum doppler shift 
        function Obj = create_channel(Obj, MDS, param)
            if param == "visualise"
                h = comm.RayleighChannel("SampleRate", Obj.S, ...
                                                    "MaximumDopplerShift", MDS, ...
                                                    "PathDelays", Obj.D, ...
                                                    "AveragePathGains", Obj.P, ...
                                                    "NormalizePathGains", true, ...
                                                    "PathGainsOutputPort", true, ...
                                                    "Visualization","Impulse and frequency responses");
               
            else
                h = comm.RayleighChannel("SampleRate", Obj.S, ...
                                                    "MaximumDopplerShift", MDS, ...
                                                    "PathDelays", Obj.D, ...
                                                    "AveragePathGains", Obj.P, ...
                                                    "NormalizePathGains", true, ...
                                                    "PathGainsOutputPort", true);
            end
            Obj.rayleigh_channel = h;
            %return Obj
        end
        % Create AWGN channel given SNR of gaussian noise
        function Obj = create_gaussian_noise(Obj, SNR)
            %signal power is 1 by default
            h = comm.AWGNChannel("NoiseMethod", "Signal to noise ratio (SNR)", ...
                                 "SNR", SNR, ...
                                 "SignalPower", 1);
            Obj.awgn_channel = h;
            Obj.snr = SNR;
            %return Obj
        end 
    end
end