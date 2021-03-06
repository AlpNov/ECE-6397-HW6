function PotentialFieldNavigation
	%PotentialFieldNavigation
	% A path planner for an n-link planar robot arm moving amoung polygonal obstacles.
	%
	% Based off chapter 5.2 in "Robot Modeling and Control" by Spong, Hutchinson,
	% and Vidyasagar
	%
	% Aaron T. Becker, 04-13-2016, atbecker@uh.edu
	%
	%  Items to complete are marked with "TODO:"
	%  ideas: save the full path, and display in another figure.
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	linkLen = [2;2;];  %lengths of each link
	%q = rand(numel(linkLen),1)*2*pi;  %robot configuration (random)
	q = [pi/2;pi/4]; %robot configuration (set)
	qprev = q; %start remembering previous config
	%qGoal = rand(numel(linkLen),1)*2*pi; %TODO: some sort of check to make sure this isn't intersecting an obstacle
	qGoal = [-pi/2;-pi/2];
	oGoal = computeOrigins(qGoal); %robot goal DH frame origins
	ptObstacles = [2,2;  -sqrt(2),sqrt(2)]; %locations of point obstacles
	
	
	alpha = 0.02; %step size for each iteration.
	% In motion planning problems, the choice for alpha is often made on an adhoc or empirical basis
	%	such as the distance to the nearest obstacle or goal
	
	%%% Parameters  (students should change these)
	zeta =   flipud(0.5*(1:numel(q))');%vector parameter that scales the forces for each degree-of-freedom
	d = 0.5; %d: the distance that defines the transition from conic toparabolic
	eta = 10*ones(numel(q),1); %eta: vector parameter that scales the repulsive forces for each degree-of-freedom
	rhoNot = 0.5; %: defines the distance of influence of the obstacle
	inLocalMinimum = false;
	t = 5;  %how many random steps to take?
	v = pi/10; % maximum random value at each step
	IsPolygonObs = false; % if tru, uses polygonal obstacles

	%TODO
	%new variables, to be sorted later
	lmlimit = 10; %how many times stuck before local min
	lmcount = 1; %local min stuck count
	lmerr = 0.1;	
	
	%setup figure showing the robot
	figure(1);clf;
	r = sum(linkLen);
	rectangle('Position',[-r,-r,2*r,2*r],'Curvature',1,'FaceColor',[.9 .9 1]) %robot workspace
	axis equal
	hold on
	% draw obstacles
	if IsPolygonObs
		ptObstacles = [1,2; -3,-1];
		polyObs1 = repmat(ptObstacles(1,:),3,1)+[.5000    0.8660
			-1.0000    0.0000
			0.5000   -0.8660];
		
		polyObs2 = repmat(ptObstacles(2,:),4,1)+[-1/2    -1
			-1/2    1
			1/2   1
			1/2 -1];
		
		p1 = fill(polyObs1(:,1),polyObs1(:,2),'r');
		set(p1,'linewidth',40,'EdgeColor',[1 .8 .8] );
		fill(polyObs1(:,1),polyObs1(:,2),'r');
		p2 = fill(polyObs2(:,1),polyObs2(:,2),'r');
		set(p2,'linewidth',40,'EdgeColor',[1 .8 .8] );
		fill(polyObs2(:,1),polyObs2(:,2),'r');
		
	else
		for j = 1:numel(ptObstacles(:,2))
			rectangle('Position',[ptObstacles(j,1)-rhoNot,ptObstacles(j,2)-rhoNot,2*rhoNot,2*rhoNot],'Curvature',1,'FaceColor',[1 .8 .8],'LineStyle','none')
		end
		plot(ptObstacles(:,1),ptObstacles(:,2),'r*')
	end
	
	%draw robot
	hGline = line([0,0],[0,1],'color','g');
	hGpts = plot([0,0],[0,1],'og');
	hRline = line([0,0],[0,1],'color','b');
	hRpts = plot([0,0],[0,1],'ob');
	harr= quiver(0,0,1,2,'color','r');
	hold off
	hTitle = title(num2str(0));
	maxIters = 2000;
	
	for iteration = 1:maxIters  %each iteration performs gradient descent one time
		%calulate error
		qErr = sum(atan2(sin(q-qGoal),cos(q-qGoal)).^2);
		oR = computeOrigins(q);
		frep = zeros([numel(q),2]);
		for j = 1:numel(ptObstacles(:,1))
			frep = frep + frepPtFloatingPoint(q, ptObstacles(j,:), eta, rhoNot);
		end
		Fvec =  fatt(q, oGoal,zeta,d) + frep;
		
		%update drawing
		updateArm(oGoal,hGline,hGpts);
		updateArm(oR,hRline,hRpts);
		set(harr, 'Xdata',oR(:,1),'Ydata',oR(:,2),'Udata',Fvec(:,1),'Vdata',Fvec(:,2));
		set(hTitle,'String',[num2str(iteration),' of ', num2str(maxIters), ' error=',num2str(qErr)])
		drawnow
		if qErr < 0.001
			break
		end
		
		%map the workspace forces to joint torques (5.2.3)
		tau = zeros(numel(q),1);
		for ic = 1:numel(q)
			tau = tau+Jv(q,ic)'* Fvec(ic,:)';
		end
		
		%Gradient descent algorithm, page 179
		q = q+alpha*tau/norm(tau);
		
		%TODO Task 3  (5pts) detect a local minimum
		% start when more than lmlimit iteration
		if (iteration > lmlimit)
			lmcount = 0;
			%check current configs against previous configs
			%if err is less than lmerr, increase count
			%else break, not a local minimum
			while ( lmcount < lmlimit )
				if ( norm(qprev(:,end - lmcount) - q) > lmerr )
					break;
				end
				lmcount = lmcount + 1;
			end
			if ( lmcount == lmlimit )
				% fprintf('local minimum\r\n');
				inLocalMinimum = true;
			end
		end

		%add current config to previous config
		if ( max(size(qprev)) >= lmlimit )
			qprev = [qprev(:,2:end) q];
		else
			qprev = [qprev q];
		end

		if inLocalMinimum
			%TODO: Task 4  (5pts) random walk:
			%execute a random walk.  If it results in collision, do not apply
			%it.
			qprime = q;
			j = 1;
			while (j < t)
				qrand = (pi/10)*(numel(q):-1:1)'.*(rand(2,1)-0.5);
				qprime = qprime+qrand;
				o = [0,0;computeOrigins(qprime)];
				%check for collision
				randcollide = false;
				for obs = 1:numel(ptObstacles(:,1))
					for jnt = 1:numel(q)
						rho = linedist([o(jnt,:);o(jnt+1,:)],ptObstacles(obs,:));
						if (rho <= rhoNot)
							randcollide = true;
						end
					end
				end

				if ( ~randcollide )
					j = j + 1;
				else
					qprime = qprime-qrand;
				end
			end
			q = qprime;
			inLocalMinimum = false;
		end
		
		%pause(0.5)
	end

	function J = Jv(q,ic) %page 177
		o = computeOrigins(q);
		Augo = [0,0;o];  %add frame 0  (augmented origin)
		% J = [z0 x (o_c - o_0),  z1 x (o_c - o_2), ...., z_(n-1) x (o_c - o_(n-1))
		J = zeros(2,numel(q));
		for c = 1:ic
			oDiff=  Augo(ic+1,:)-Augo(c,:);
			J(1,c) = -oDiff(2);
			J(2,c) = oDiff(1);
		end
		
	end

	function Fvec =  fatt(q, oGoal,zeta,d)
		%fatt computes the forces that attract each DH frame origin to their goal
		%configurations, given by equation 5.4 in RD&C
		%q: configuration of the arm
		%oGoal: goal position of each DH frame origin
		%zeta: vector parameter that scales the forces for each degree-of-freedom
		%d: the distance that defines the transition from conic toparabolic
		Fvec = zeros(numel(q),2); %Force vector to attract each origin to the goal
		o = computeOrigins(q); % o is a vector of the origins for DH frames of a planar robot arm.
		
		for i = 1:numel(q) % compute attractive force for each origin
			err = dist(o(i,:),oGoal(i,:));
			if err < d
				Fvec(i,:)= -zeta(i)*( o(i,:)-oGoal(i,:)  );
			else
				Fvec(i,:)= -d*zeta(i)*( o(i,:)-oGoal(i,:)  )/err;
			end
		end
	end

	function o = computeOrigins(q)
		%Computes o, the (x,y) coordinate of the DH frame for each link in q
		qSum = cumsum(q);
		oDelta = [linkLen,linkLen].*[cos(qSum),sin(qSum)];
		o = cumsum(oDelta);
	end

	function Fvec =  frepPt(q, pObstacle, eta, rhoNot)
		% TODO: Task 1  (5pts) repulsion from point obstacle
		%frepPt computes the forces that repel each DH frame origin from a point
		%at positon pObstacle, given by equation 5.6 & 5.7 in RD&C
		%q: configuration of the arm
		%pObstacle: xy position of the point obstacle
		%eta: vector parameter that scales the forces for each degree-of-freedom
		%rhoNot: defines the distance of influence of the obstacle
		Fvec = zeros(numel(q),2); %Force vector to repulse each origin from the obstacle
		o = computeOrigins(q); % o is a vector of the origins for DH frames of a planar robot arm.
		
		for i = 1:numel(q) % compute attractive force for each origin
			err = dist(o(i,:),oGoal(i,:));
			if err < d
				Fvec(i,:)= -zeta(i)*( o(i,:)-oGoal(i,:)  );
			else
				Fvec(i,:)= -d*zeta(i)*( o(i,:)-oGoal(i,:)  )/err;
			end
		end
	end

	function Fvec =  frepPtFloatingPoint(q, pObstacle, eta, rhoNot)
		% Task 2  (Graduate students 5pts, Undergrads, 5pts E.C.):
		%computes the forces that repel a point on the link that is closest to any workspace obstacle
		%at positon pObstacle, given by equation 5.6 & 5.7 in RD&C
		%q: configuration of the arm
		%pObstacle: xy position of the point obstacle
		%eta: vector parameter that scales the forces for each degree-of-freedom
		%rhoNot: defines the distance of influence of the obstacle
		Fvec = zeros(numel(q),2); %Force vector to attract each origin to the goal
		o = computeOrigins(q); % o is a vector of the origins for DH frames of a planar robot arm.
		o = [0,0;o]; %add 0,0 as a joint origin to calculate distance from arm to obstacle
		
		for i = 1:numel(q) % compute attractive force for each origin
			rho = linedist([o(i,:);o(i+1,:)],pObstacle); %distance to obstacle
			if rho < rhoNot 
				Fvec(i,:)= eta(i)*(1/rho-1/rhoNot)*(1/(rho*rho))*(o(i+1,:) - pObstacle);
			else
				Fvec(i,:)= 0;
			end
		end
	end

	function updateArm(o,hline,hpts) %redraws arm
		set(hline, 'xdata',[0;o(:,1)], 'ydata',[0;o(:,2)]);
		set(hpts, 'xdata',[0;o(:,1)], 'ydata',[0;o(:,2)]);
	end

	function d = dist(a,b)% norm 2 distance between two vectors
		d=sum((a-b).^2)^.5;
	end

	function d = linedist(lineQ,P) % distance between a line segment 
		%calculate distance between point P and line segment specified by lineQ
		%lineQ - 2 points that make up a line
		%P - point
		dQ1 = P-lineQ(1,:);
		dQ2 = P-lineQ(2,:);
		line = lineQ(2,:) - lineQ(1,:);
		if ( acos(sum(dQ1.*line)/(norm(dQ1)*norm(line))) > pi/2 )
			d = norm(dQ1);
		elseif ( acos(sum(dQ2.*(-line))/(norm(dQ2)*norm(line))) > pi/2 )
			d = norm(dQ2);
		else
			% if 2D lines and point, append 0 for z coordinate for cross product
			if (numel(line) == 2)
				d = norm(cross([dQ1 0],[line 0]))/(norm(dQ1)*norm(line));
			else
				d = norm(cross(dQ1,line))/(norm(dQ1)*norm(line));
			end
		end
	end
end
