classdef equalisers 
    methods (Static)
        function b = NO_Estimator(a)
            b = copy(a);
        end

        function b = MMSE_Estimator(a)
            
        end

        function c = covariance(a, b)
            c = cov(a, b);
        end
        % LS estimator takes channel class as input, clones the channel to
        % isolate it, and performs equalisation on cloned channel. 
        function b = LS_Estimator(a, param2)
            if ~exist('param2', 'var')
                param2 = "false";
            end

            b = copy(a);
            % pilot transfer function
            pilot_h = b.rx_pilots ./ b.tx_pilots;
           
            % t1 is location of pilots 
            t1 = b.pilot_locs;
            % t3 is the whole message length
            t3 = b.message_locs;
            % interpolate pilot transfer function
            vq = interp1(t1, pilot_h, t3, 'spline');
            % remove pilots before applying interpolated tf
                        
            b.no_pilot_data = b.no_pilot_data ./ vq;
            % visualise QAM before demodulation (dirty)
            if param2 == "visualise"
                b.vis_QAM_no_pilots_dirty();
            end
            % demodulate
            b.demodulated_data = b.demodulateQAM4(b.no_pilot_data);
        end
    end
end