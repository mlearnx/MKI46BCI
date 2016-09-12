% Made by Ceci Verbaarschot
%
% Function to determine the EMG threshold for action. 
% 
% perc: value between 0 and 1. Determines the difficulty level for acting. 
%
% The threshold for acting is defined as 
% the mean EMG activity in rest + (perc * the max difference between EMG in action and rest) 
function threshold = setEMGthreshold(datafile,perc)
    % Add all necessary paths
    run /Users/ceciverbaarschot/buffer_bci/matlab/utilities/initPaths.m % check path when ran from a different computer
    
    if ~exist('perc')
        perc = 0.8; % perc is default set to 0.8
    end

    % slice recorded data
    [data,devents,hdr,allevents]=sliceraw(datafile,'startSet',{'move'}, 'trlen_ms', 3000); % slice 3s trials  
    
    X = data; % keep original data
    
    % keep only EMG channels and subtract bipolar EMG channels
    for t=1:length(data)
        X(t).buf(1,:) = data(t).buf(2,:)-data(t).buf(1,:); % right hand: check which channels to select
        X(t).buf(2,:) = data(t).buf(4,:)-data(t).buf(3,:); % left hand: check which channels to select
        X(t).buf(3:end,:) = [];
    end
    
    % spectrally filter to the range of interest
    fs=hdr.Fs;
    freqband = [47 51 250 256];
    outsz=[size(X,2) size(X,2)];
    if (size(X,2)>10 && ~isempty(fs)) 
      len=size(X,2);
      filt=mkFilter(freqband,floor(len/2),fs/len);
      X   =fftfilter(X,filt,outsz,2,2);
    end
    
    % Rectify the signal = take absolute value
    for t=1:length(X)
        X(t).buf = abs(X(t).buf);  
    end
    
    % Low pass filter the signal (cutoff =~ 15 Hz, since tau = 10ms for EMG), Welter et al., 2000; 1st order)
    for ch = 1:size(X(1).buf,1) % Per channel
        for t=1:length(X)
            [B,A] = butter(1,16/128,'low');
            X(t).buf(ch,:) = filter(B,A,X(t).buf(ch,:));  
        end
    end
    
    % Plot data
    %time = [0.01:1/100:3];
    %figure;plot(time,X(1).buf);
    
    rightMoveData = X(find(strcmp({devents.value},'Rechter hand'))); 
    for t=1:length(rightMoveData)
        rightMoveData(t).buf(1,:) = [];
    end
    leftMoveData = X(find(strcmp({devents.value},'Linker hand')));
    for t=1:length(leftMoveData)
        leftMoveData(t).buf(2,:) = [];
    end
    restData = X(find(strcmp({devents.value},'relax')));
    bothMoveData = X(find(strcmp({devents.value},'Beide handen')));
    
    % define mean EMG activity in rest and action
    meanEMGrest = mean(mean([restData(:).buf],2));
    meanEMGleft = mean(mean([leftMoveData(:).buf],2)); % select channels
    meanEMGright = mean(mean([rightMoveData(:).buf],2)); % select channels
    meanEMGboth = mean(mean([bothMoveData(:).buf],2));
    
    % define max EMG activity in action
    meanEMGaction = max([meanEMGleft,meanEMGright,meanEMGboth]);
    
    % max difference between rest and action
    maxdiffEMG = abs(meanEMGrest - meanEMGaction);

    % set threshold for movement
    threshold = (meanEMGrest + (perc*maxdiffEMG))/1000;
    
    % output the result
    sz = [100 300]; % figure size
    screensize = get(0,'ScreenSize');
    xpos = ceil((screensize(3)-sz(2))/2); % center the figure on the
    Screen horizontally
    ypos = ceil((screensize(4)-sz(1))/2); % center the figure on the
    Screen vertically
    figure('position',[xpos, ypos, sz(2), sz(1)],...
        'units','pixels','MenuBar','none');
    
    instruction = sprintf(['Threshold = ', num2str(round(threshold)), 'mV' ,'\nDifficulty = ',num2str(perc), ' perc']);
    text(0,0.5,instruction,'Color','black','FontSize',20);
    set(gca,'visible','off');
end